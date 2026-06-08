#!/usr/bin/env bash

TICKERS_FILE="$(dirname "$0")/tickers.txt"
DISPLAY_INTERVAL=3
REFRESH_INTERVAL=300
CACHE_FILE="/tmp/waybar-tickers-cache.json"

signal() {
    awk -v p="$1" 'BEGIN { if (p > 0.1) print "↑"; else if (p < -0.1) print "↓"; else print "→" }'
}

css_class() {
    awk -v p="$1" 'BEGIN { if (p > 0.1) print "up"; else if (p < -0.1) print "down"; else print "neutral" }'
}

fetch_ticker() {
    local sym="$1"
    local json prev curr change
    json=$(curl -s --max-time 10 \
        -H "User-Agent: Mozilla/5.0" \
        "https://query1.finance.yahoo.com/v8/finance/chart/${sym}?interval=1d&range=2d")
    prev=$(echo "$json" | jq -r '.chart.result[0].indicators.quote[0].close[-2] // empty')
    curr=$(echo "$json" | jq -r '.chart.result[0].indicators.quote[0].close[-1] // empty')
    [[ -z "$prev" || -z "$curr" ]] && return 1
    change=$(awk -v c="$curr" -v p="$prev" 'BEGIN { printf "%.4f", (c - p) / p * 100 }')
    echo "$sym $curr $change"
}

refresh_cache() {
    local tickers=("$@")
    local tmp
    tmp=$(mktemp)
    local first=1
    printf '{' > "$tmp"
    for sym in "${tickers[@]}"; do
        local result curr change
        result=$(fetch_ticker "$sym") || continue
        read -r _ curr change <<< "$result"
        [[ "$first" -eq 0 ]] && printf ',' >> "$tmp"
        printf '"%s":{"price":%s,"change":%s}' "$sym" "$curr" "$change" >> "$tmp"
        first=0
    done
    printf '}' >> "$tmp"
    mv "$tmp" "$CACHE_FILE"
}

read_tickers() {
    grep -v '^\s*#' "$TICKERS_FILE" | grep -v '^\s*$'
}

mapfile -t TICKERS < <(read_tickers)
refresh_cache "${TICKERS[@]}" &
REFRESH_PID=$!

printf '{"text":"⟳ …","tooltip":"carregando cotações","class":"neutral"}\n'

i=0
last_refresh=$(date +%s)

while true; do
    sleep "$DISPLAY_INTERVAL"

    if [[ -n "$REFRESH_PID" ]]; then
        wait "$REFRESH_PID" 2>/dev/null
        REFRESH_PID=""
    fi

    mapfile -t TICKERS < <(read_tickers)
    [[ "${#TICKERS[@]}" -eq 0 ]] && continue

    sym="${TICKERS[$((i % ${#TICKERS[@]}))]}"
    (( i++ ))

    if [[ -f "$CACHE_FILE" ]]; then
        price=$(jq -r --arg s "$sym" '.[$s].price // empty' "$CACHE_FILE")
        change=$(jq -r --arg s "$sym" '.[$s].change // empty' "$CACHE_FILE")

        if [[ -n "$price" && -n "$change" ]]; then
            sig=$(signal "$change")
            css=$(css_class "$change")
            price_fmt=$(awk -v p="$price" 'BEGIN { printf "%.2f", p }')
            change_fmt=$(awk -v c="$change" 'BEGIN { printf "%+.2f", c }')
            printf '{"text":"%s %s %s","tooltip":"%s%%","class":"%s"}\n' \
                "$sym" "$sig" "$price_fmt" "$change_fmt" "$css"
        fi
    fi

    now=$(date +%s)
    if (( now - last_refresh >= REFRESH_INTERVAL )); then
        refresh_cache "${TICKERS[@]}" &
        last_refresh=$now
    fi
done
