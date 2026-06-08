# waybar-tickers

Waybar module for rotating stock quotes via Yahoo Finance. No external dependencies.

## Format

```
AAPL ↓ 301.54 USD -1.89%
PETR4.SA ↑ 41.22 BRL +0.81%
BTC-USD ↑ 63725.70 USD +0.77%
```

Signals: `↑` up, `→` neutral, `↓` down (threshold: ±0.1%).  
CSS classes: `up`, `neutral`, `down` — style via `style.css`.

## Dependencies

`curl` and `jq` — available in most distros.

## Installation

```bash
cp tickers.sh ~/.config/waybar/scripts/tickers.sh
chmod +x ~/.config/waybar/scripts/tickers.sh

cp tickers.txt ~/.config/waybar/scripts/tickers.txt
```

Add to `config.jsonc` (see `waybar-config-snippet.jsonc`).

## tickers.txt

One ticker per line. Use `.SA` suffix for Brazilian stocks. Lines starting with `#` are ignored.

```
AAPL
PETR4.SA
BTC-USD
```

## Parameters (tickers.sh)

| Variable | Default | Description |
|---|---|---|
| `REFRESH_INTERVAL` | 300 s | Data refresh interval |

The display interval per ticker is controlled by `interval` in `config.jsonc` (default: 3 s).
