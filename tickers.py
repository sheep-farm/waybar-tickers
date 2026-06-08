#!/usr/bin/env python3
"""Waybar module: rotating stock ticker using yfinance."""

import json
import threading
import time
from pathlib import Path

import yfinance as yf

TICKERS_FILE = Path(__file__).parent / "tickers.txt"
DISPLAY_INTERVAL = 3    # seconds per ticker
REFRESH_INTERVAL = 300  # seconds between data fetches (5 min)


def signal(change_pct: float) -> str:
    if change_pct > 0.1:
        return "↑"
    if change_pct < -0.1:
        return "↓"
    return "→"


def fetch_all(symbols: list[str]) -> dict:
    if not symbols:
        return {}
    try:
        df = yf.download(symbols, period="2d", auto_adjust=True, progress=False, threads=True)
        closes = df["Close"]
        if len(symbols) == 1 and not hasattr(closes, "columns"):
            closes = closes.to_frame(name=symbols[0])
        result = {}
        for sym in symbols:
            try:
                col = closes[sym].dropna()
                if len(col) >= 2:
                    prev, curr = col.iloc[-2], col.iloc[-1]
                    result[sym] = (float(curr), float((curr - prev) / prev * 100))
            except Exception:
                pass
        return result
    except Exception:
        return {}


def read_tickers() -> list[str]:
    if not TICKERS_FILE.exists():
        return []
    return [
        line.strip()
        for line in TICKERS_FILE.read_text().splitlines()
        if line.strip() and not line.startswith("#")
    ]


def main():
    cache: dict = {}
    lock = threading.Lock()

    def refresh_loop():
        while True:
            tickers = read_tickers()
            new = fetch_all(tickers)
            with lock:
                cache.update(new)
            time.sleep(REFRESH_INTERVAL)

    threading.Thread(target=refresh_loop, daemon=True).start()

    # placeholder enquanto o primeiro fetch não chega
    print(json.dumps({"text": "⟳ …", "tooltip": "carregando cotações", "class": "neutral"}), flush=True)

    i = 0
    while True:
        time.sleep(DISPLAY_INTERVAL)
        tickers = read_tickers()
        if not tickers:
            continue

        sym = tickers[i % len(tickers)]
        i += 1

        with lock:
            entry = cache.get(sym)

        if entry:
            price, change = entry
            sig = signal(change)
            css = "up" if change > 0.1 else "down" if change < -0.1 else "neutral"
            print(
                json.dumps({
                    "text": f"{sym} {sig} {price:.2f}",
                    "tooltip": f"{change:+.2f}%",
                    "class": css,
                }),
                flush=True,
            )


if __name__ == "__main__":
    main()
