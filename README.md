# waybar-tickers

Waybar module for rotating stock quotes via Yahoo Finance. No external dependencies.

https://github.com/sheep-farm/waybar-tickers

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

Add to `config.jsonc`:

```jsonc
"custom/tickers": {
    "exec": "~/.config/waybar/scripts/tickers.sh",
    "return-type": "json",
    "interval": 3
}
```

Add `"custom/tickers"` to `modules-left`, `modules-center`, or `modules-right`.

Add to `style.css`:

```css
#custom-tickers {
    padding: 0 10px;
}

#custom-tickers.up {
    color: #a6e3a1;
}

#custom-tickers.down {
    color: #f38ba8;
}

#custom-tickers.neutral {
    color: #f9e2af;
}
```

## tickers.txt

One ticker per line. Use `.SA` suffix for Brazilian stocks. Lines starting with `#` are ignored.

```
AAPL
PETR4.SA
BTC-USD
```

Changes to `tickers.txt` are picked up live — no Waybar restart needed. Added tickers are fetched immediately on first display; removed tickers are skipped on the next cycle.

## Scroll mode

Set `SCROLL=1` in `tickers.sh` to enable a continuous horizontal ticker tape. All tickers scroll left in a fixed-width window, each colored individually via Pango markup (`up` → green, `down` → red, `neutral` → yellow).

Also set `interval` to `0` in `config.jsonc`. With `interval: 0`, Waybar respawns the script immediately after each exit, producing smooth scrolling at ~10–20 chars/second (controlled by bash execution time rather than a fixed timer):

```jsonc
"custom/tickers": {
    "exec": "~/.config/waybar/scripts/tickers.sh",
    "return-type": "json",
    "interval": 0
}
```

In scroll mode the CSS `.up` / `.down` / `.neutral` classes are not used (colors are inline). The `style.css` block for `#custom-tickers` still applies for padding and font.

## Parameters (tickers.sh)

| Variable | Default | Description |
|---|---|---|
| `FORMAT` | `{ticker} {arrow} {price} {currency} {change}%` | Main text format |
| `TOOLTIP` | `{change}%` | Tooltip format |
| `REFRESH_INTERVAL` | 300 s | Data refresh interval |
| `SCROLL` | `0` | Set to `1` to enable scroll mode |
| `DISPLAY_WIDTH` | `40` | Visible characters in scroll mode |
| `SCROLL_STEP` | `1` | Characters advanced per invocation (scroll mode) |
| `SEPARATOR` | `    ·    ` | Separator between tickers in scroll mode |

In rotation mode (`SCROLL=0`), use `interval: 3` in `config.jsonc`. In scroll mode (`SCROLL=1`), use `interval: 0`.

### Placeholders

| Placeholder | Example |
|---|---|
| `{ticker}` | `AAPL` |
| `{arrow}` | `↑` |
| `{price}` | `301.54` |
| `{currency}` | `USD` |
| `{change}` | `+1.89%` (signed) |
| `{change_abs}` | `1.89` (absolute value) |
