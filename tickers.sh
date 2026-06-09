#!/usr/bin/env bash
# Runs once per invocation (interval: 3 in config).
# Keeps a cache in /tmp to avoid fetching on every call.

TICKERS_FILE="$(dirname "$0")/tickers.txt"
CACHE_FILE="/tmp/waybar-tickers.json"
STATE_FILE="/tmp/waybar-tickers.state"
CHECKSUM_FILE="/tmp/waybar-tickers.checksum"
REFRESH_INTERVAL=300

# Placeholders: {ticker} {arrow} {price} {currency} {change} {change_abs}
FORMAT="{ticker} {arrow} {price} {currency} {change}%"
TOOLTIP="{change}%"

read_tickers() {
    grep -v '^\s*#' "$TICKERS_FILE" 2>/dev/null | grep -v '^\s*$'
}

fetch_cache() {
    local tickers=("$@")
    local tmp first=1
    tmp=$(mktemp)
    printf '{' > "$tmp"
    for sym in "${tickers[@]}"; do
        local json prev curr currency change
        json=$(curl -s --max-time 10 \
            -H "User-Agent: Mozilla/5.0" \
            "https://query1.finance.yahoo.com/v8/finance/chart/${sym}?interval=1d&range=2d")
        prev=$(printf '%s' "$json" | jq -r '.chart.result[0].indicators.quote[0].close[-2] // empty')
        curr=$(printf '%s' "$json" | jq -r '.chart.result[0].indicators.quote[0].close[-1] // empty')
        currency=$(printf '%s' "$json" | jq -r '.chart.result[0].meta.currency // empty')
        [[ -z "$prev" || -z "$curr" ]] && continue
        change=$(awk -v c="$curr" -v p="$prev" 'BEGIN { printf "%.4f", (c-p)/p*100 }')
        [[ "$first" -eq 0 ]] && printf ',' >> "$tmp"
        printf '"%s":{"price":%s,"change":%s,"currency":"%s"}' "$sym" "$curr" "$change" "$currency" >> "$tmp"
        first=0
    done
    printf '}' >> "$tmp"
    mv "$tmp" "$CACHE_FILE"
}

render() {
    local template="$1" ticker="$2" arrow="$3" price="$4" currency="$5" change="$6" change_abs="$7"
    printf '%s' "$template" \
        | sed "s/{ticker}/$ticker/g" \
        | sed "s/{arrow}/$arrow/g" \
        | sed "s/{price}/$price/g" \
        | sed "s/{currency}/$currency/g" \
        | sed "s/{change}/$change/g" \
        | sed "s/{change_abs}/$change_abs/g"
}

mapfile -t TICKERS < <(read_tickers)
[[ "${#TICKERS[@]}" -eq 0 ]] && exit 0

checksum=$(md5sum "$TICKERS_FILE" 2>/dev/null | cut -d' ' -f1)
prev_checksum=""
[[ -f "$CHECKSUM_FILE" ]] && prev_checksum=$(cat "$CHECKSUM_FILE")

if [[ "$checksum" != "$prev_checksum" ]]; then
    printf '%s' "$checksum" > "$CHECKSUM_FILE"
    printf '0' > "$STATE_FILE"
    fetch_cache "${TICKERS[@]}"
else
    now=$(date +%s)
    cache_age=999999
    [[ -f "$CACHE_FILE" ]] && cache_age=$(( now - $(stat -c %Y "$CACHE_FILE") ))
    (( cache_age >= REFRESH_INTERVAL )) && fetch_cache "${TICKERS[@]}"
fi

[[ ! -f "$CACHE_FILE" ]] && exit 0

i=0
[[ -f "$STATE_FILE" ]] && i=$(cat "$STATE_FILE")
sym="${TICKERS[$((i % ${#TICKERS[@]}))]}"
printf '%d' $(( (i + 1) % ${#TICKERS[@]} )) > "$STATE_FILE"

price=$(jq -r --arg s "$sym" '.[$s].price // empty' "$CACHE_FILE")

# ticker missing from cache (added live) — fetch immediately
if [[ -z "$price" ]]; then
    fetch_cache "${TICKERS[@]}"
    price=$(jq -r --arg s "$sym" '.[$s].price // empty' "$CACHE_FILE")
fi

change=$(jq -r --arg s "$sym" '.[$s].change // empty' "$CACHE_FILE")
currency=$(jq -r --arg s "$sym" '.[$s].currency // empty' "$CACHE_FILE")
[[ -z "$price" || -z "$change" ]] && exit 0

css=$(awk -v p="$change" 'BEGIN { if (p > 0.1) print "up"; else if (p < -0.1) print "down"; else print "neutral" }')
arrow=$(awk -v p="$change" 'BEGIN { if (p > 0.1) print "↑"; else if (p < -0.1) print "↓"; else print "→" }')
price_fmt=$(awk -v p="$price" 'BEGIN { printf "%.2f", p }')
change_fmt=$(awk -v c="$change" 'BEGIN { printf "%+.2f", c }')
change_abs=$(awk -v c="$change" 'BEGIN { printf "%.2f", (c < 0 ? -c : c) }')

text=$(render "$FORMAT" "$sym" "$arrow" "$price_fmt" "$currency" "$change_fmt" "$change_abs")
tooltip=$(render "$TOOLTIP" "$sym" "$arrow" "$price_fmt" "$currency" "$change_fmt" "$change_abs")

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tooltip" "$css"
