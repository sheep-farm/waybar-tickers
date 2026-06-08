#!/usr/bin/env bash
# Roda uma vez por invocação (interval: 3 no config).
# Mantém cache em /tmp para evitar fetch a cada chamada.

TICKERS_FILE="$(dirname "$0")/tickers.txt"
CACHE_FILE="/tmp/waybar-tickers.json"
STATE_FILE="/tmp/waybar-tickers.state"
REFRESH_INTERVAL=300

signal() {
    awk -v p="$1" 'BEGIN { if (p > 0.1) print "up"; else if (p < -0.1) print "down"; else print "neutral" }'
}

arrow() {
    awk -v p="$1" 'BEGIN { if (p > 0.1) print "up"; else if (p < -0.1) print "down"; else print "neutral" }'
}

read_tickers() {
    grep -v '^\s*#' "$TICKERS_FILE" 2>/dev/null | grep -v '^\s*$'
}

fetch_cache() {
    local tickers=("$@")
    local tmp first=1
    tmp=$(mktemp)
    printf '{' > "$tmp"
    for sym in "${tickers[@]}"; do
        local json prev curr change
        json=$(curl -s --max-time 10 \
            -H "User-Agent: Mozilla/5.0" \
            "https://query1.finance.yahoo.com/v8/finance/chart/${sym}?interval=1d&range=2d")
        prev=$(printf '%s' "$json" | jq -r '.chart.result[0].indicators.quote[0].close[-2] // empty')
        curr=$(printf '%s' "$json" | jq -r '.chart.result[0].indicators.quote[0].close[-1] // empty')
        [[ -z "$prev" || -z "$curr" ]] && continue
        change=$(awk -v c="$curr" -v p="$prev" 'BEGIN { printf "%.4f", (c-p)/p*100 }')
        [[ "$first" -eq 0 ]] && printf ',' >> "$tmp"
        printf '"%s":{"price":%s,"change":%s}' "$sym" "$curr" "$change" >> "$tmp"
        first=0
    done
    printf '}' >> "$tmp"
    mv "$tmp" "$CACHE_FILE"
}

mapfile -t TICKERS < <(read_tickers)
[[ "${#TICKERS[@]}" -eq 0 ]] && echo '{}' && exit 0

# atualiza cache se expirado ou ausente
now=$(date +%s)
cache_age=999999
[[ -f "$CACHE_FILE" ]] && cache_age=$(( now - $(stat -c %Y "$CACHE_FILE") ))
if (( cache_age >= REFRESH_INTERVAL )); then
    fetch_cache "${TICKERS[@]}"
fi

[[ ! -f "$CACHE_FILE" ]] && exit 0

# avança o índice de exibição
i=0
[[ -f "$STATE_FILE" ]] && i=$(cat "$STATE_FILE")
sym="${TICKERS[$((i % ${#TICKERS[@]}))]}"
printf '%d' $(( (i + 1) % ${#TICKERS[@]} )) > "$STATE_FILE"

price=$(jq -r --arg s "$sym" '.[$s].price // empty' "$CACHE_FILE")
change=$(jq -r --arg s "$sym" '.[$s].change // empty' "$CACHE_FILE")
[[ -z "$price" || -z "$change" ]] && exit 0

css=$(awk -v p="$change" 'BEGIN { if (p > 0.1) print "up"; else if (p < -0.1) print "down"; else print "neutral" }')
arr=$(awk -v p="$change" 'BEGIN { if (p > 0.1) print "↑"; else if (p < -0.1) print "↓"; else print "→" }')
price_fmt=$(awk -v p="$price" 'BEGIN { printf "%.2f", p }')
change_fmt=$(awk -v c="$change" 'BEGIN { printf "%+.2f", c }')

printf '{"text":"%s %s %s","tooltip":"%s%%","class":"%s"}\n' \
    "$sym" "$arr" "$price_fmt" "$change_fmt" "$css"
