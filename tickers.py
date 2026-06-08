#!/usr/bin/env python3
"""Waybar module: rotating stock ticker using yfinance."""

import json
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
    data = {}
    for sym in symbols:
        try:
            hist = yf.Ticker(sym).history(period="2d")
            if len(hist) >= 2:
                prev = hist["Close"].iloc[-2]
                curr = hist["Close"].iloc[-1]
                change = (curr - prev) / prev * 100
                data[sym] = (curr, change)
        except Exception:
            pass
    return data


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
    last_fetch: float = 0
    i = 0

    while True:
        tickers = read_tickers()
        now = time.time()

        if not cache or now - last_fetch > REFRESH_INTERVAL:
            cache = fetch_all(tickers)
            last_fetch = now

        if tickers:
            sym = tickers[i % len(tickers)]
            i += 1

            if sym in cache:
                price, change = cache[sym]
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

        time.sleep(DISPLAY_INTERVAL)


if __name__ == "__main__":
    main()
