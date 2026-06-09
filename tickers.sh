#!/usr/bin/env bash
# Runs once per invocation (interval: 1 in scroll mode, 3 otherwise).
# Keeps a cache in /tmp to avoid fetching on every call.

VERSION="1.0.0"

TICKERS_FILE="$(dirname "$0")/tickers.txt"
CACHE_FILE="/tmp/waybar-tickers.json"
STATE_FILE="/tmp/waybar-tickers.state"
SCROLL_FILE="/tmp/waybar-tickers.scroll"
CHECKSUM_FILE="/tmp/waybar-tickers.checksum"
REFRESH_INTERVAL=300

# Placeholders: {ticker} {arrow} {price} {currency} {change} {change_abs}
FORMAT="{ticker} {arrow} {price} {currency} {change}%"

# SCROLL=1: horizontal ticker tape. SCROLL=0: single-ticker rotation.
# When SCROLL=1, set interval: 0 in config.jsonc (Waybar respawns immediately).
# When SCROLL=0, set interval: 3 in config.jsonc.
SCROLL=1
SEPARATOR="    ·    "
DISPLAY_WIDTH=40
SCROLL_STEP=1

read_tickers() {
    grep -v '^\s*#' "$TICKERS_FILE" 2>/dev/null | grep -v '^\s*$'
}

fetch_cache() {
    local tickers=("$@")
    local tmp first=1 fresh=0
    tmp=$(mktemp)
    printf '{' > "$tmp"
    for sym in "${tickers[@]}"; do
        local body http_code curr prev currency change
        body=$(mktemp)
        http_code=$(curl -s -o "$body" --max-time 10 \
            -H "User-Agent: Mozilla/5.0" \
            -w "%{http_code}" \
            "https://query1.finance.yahoo.com/v8/finance/chart/${sym}?interval=1d&range=2d")
        if [[ "$http_code" != "200" ]]; then
            rm -f "$body"
            local cp cc cu
            cp=$(jq -r --arg s "$sym" '.[$s].price // empty' "$CACHE_FILE" 2>/dev/null)
            cc=$(jq -r --arg s "$sym" '.[$s].change // empty' "$CACHE_FILE" 2>/dev/null)
            cu=$(jq -r --arg s "$sym" '.[$s].currency // empty' "$CACHE_FILE" 2>/dev/null)
            if [[ -n "$cp" && -n "$cc" ]]; then
                [[ "$first" -eq 0 ]] && printf ',' >> "$tmp"
                printf '"%s":{"price":%s,"change":%s,"currency":"%s"}' "$sym" "$cp" "$cc" "$cu" >> "$tmp"
                first=0
            fi
            continue
        fi
        curr=$(jq -r '.chart.result[0].meta.regularMarketPrice // empty' "$body")
        prev=$(jq -r '.chart.result[0].meta.chartPreviousClose // empty' "$body")
        currency=$(jq -r '.chart.result[0].meta.currency // empty' "$body")
        rm -f "$body"
        [[ -z "$prev" || -z "$curr" ]] && continue
        change=$(awk -v c="$curr" -v p="$prev" 'BEGIN { printf "%.4f", (c-p)/p*100 }')
        [[ "$first" -eq 0 ]] && printf ',' >> "$tmp"
        printf '"%s":{"price":%s,"change":%s,"currency":"%s"}' "$sym" "$curr" "$change" "$currency" >> "$tmp"
        first=0
        (( fresh++ ))
    done
    printf '}' >> "$tmp"
    if [[ "$fresh" -gt 0 ]]; then
        mv "$tmp" "$CACHE_FILE"
    else
        rm -f "$tmp"
        [[ -f "$CACHE_FILE" ]] && touch "$CACHE_FILE"
    fi
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

build_tooltip() {
    local tip_arrows=() tip_tickers=() tip_prices=() tip_currencies=() tip_changes=() tip_colors=()
    for sym in "${TICKERS[@]}"; do
        local price change currency arrow price_fmt change_fmt color
        price=$(jq -r --arg s "$sym" '.[$s].price // empty' "$CACHE_FILE")
        change=$(jq -r --arg s "$sym" '.[$s].change // empty' "$CACHE_FILE")
        currency=$(jq -r --arg s "$sym" '.[$s].currency // empty' "$CACHE_FILE")
        [[ -z "$price" || -z "$change" ]] && continue
        arrow=$(awk -v p="$change" 'BEGIN { if (p > 0.1) print "↑"; else if (p < -0.1) print "↓"; else print "→" }')
        price_fmt=$(awk -v p="$price" 'BEGIN { printf "%.2f", p }')
        change_fmt=$(awk -v c="$change" 'BEGIN { printf "%+.2f", c }')
        color=$(awk -v p="$change" 'BEGIN { if (p > 0.1) print "#a6e3a1"; else if (p < -0.1) print "#f38ba8"; else print "#f9e2af" }')
        tip_arrows+=("$arrow")
        tip_tickers+=("$sym")
        tip_prices+=("$price_fmt")
        tip_currencies+=("$currency")
        tip_changes+=("${change_fmt}%")
        tip_colors+=("$color")
    done
    local max_t=0 max_p=0 max_c=0
    for (( k=0; k<${#tip_tickers[@]}; k++ )); do
        (( ${#tip_tickers[k]} > max_t )) && max_t=${#tip_tickers[k]}
        (( ${#tip_prices[k]} > max_p )) && max_p=${#tip_prices[k]}
        (( ${#tip_changes[k]} > max_c )) && max_c=${#tip_changes[k]}
    done
    local lines=()
    for (( k=0; k<${#tip_tickers[@]}; k++ )); do
        local line
        line=$(printf "%s  %-*s  %*s %-3s  %*s" \
            "${tip_arrows[k]}" "$max_t" "${tip_tickers[k]}" \
            "$max_p" "${tip_prices[k]}" "${tip_currencies[k]}" \
            "$max_c" "${tip_changes[k]}")
        lines+=("<span font_family='monospace' color='${tip_colors[k]}'>${line}</span>")
    done
    local updated="—"
    if [[ -f "$CACHE_FILE" ]]; then
        local mtime
        mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null)
        updated=$(date -d "@${mtime}" '+%d %b %H:%M' 2>/dev/null || echo "—")
    fi
    lines+=("")
    lines+=("<span font_family='monospace' color='#6c7086'>  Last update: ${updated}</span>")
    printf '%s\n' "${lines[@]}" | sed 's/$/\\n/' | tr -d '\n'
}

mapfile -t TICKERS < <(read_tickers)
[[ "${#TICKERS[@]}" -eq 0 ]] && exit 0

checksum=$(md5sum "$TICKERS_FILE" 2>/dev/null | cut -d' ' -f1)
prev_checksum=""
[[ -f "$CHECKSUM_FILE" ]] && prev_checksum=$(cat "$CHECKSUM_FILE")

if [[ "$checksum" != "$prev_checksum" ]]; then
    printf '%s' "$checksum" > "$CHECKSUM_FILE"
    printf '0' > "$STATE_FILE"
    printf '0' > "$SCROLL_FILE"
    fetch_cache "${TICKERS[@]}"
else
    now=$(date +%s)
    cache_age=999999
    [[ -f "$CACHE_FILE" ]] && cache_age=$(( now - $(stat -c %Y "$CACHE_FILE") ))
    (( cache_age >= REFRESH_INTERVAL )) && fetch_cache "${TICKERS[@]}"
fi

[[ ! -f "$CACHE_FILE" ]] && exit 0

if [[ "$SCROLL" -eq 1 ]]; then
    seg_starts=()
    seg_lens=()
    seg_texts=()
    seg_colors=()
    sep_len=${#SEPARATOR}
    pos=0
    first=1

    for sym in "${TICKERS[@]}"; do
        price=$(jq -r --arg s "$sym" '.[$s].price // empty' "$CACHE_FILE")
        change=$(jq -r --arg s "$sym" '.[$s].change // empty' "$CACHE_FILE")
        currency=$(jq -r --arg s "$sym" '.[$s].currency // empty' "$CACHE_FILE")
        [[ -z "$price" || -z "$change" ]] && continue

        arrow=$(awk -v p="$change" 'BEGIN { if (p > 0.1) print "↑"; else if (p < -0.1) print "↓"; else print "→" }')
        price_fmt=$(awk -v p="$price" 'BEGIN { printf "%.2f", p }')
        change_fmt=$(awk -v c="$change" 'BEGIN { printf "%+.2f", c }')
        change_abs=$(awk -v c="$change" 'BEGIN { printf "%.2f", (c < 0 ? -c : c) }')

        text=$(render "$FORMAT" "$sym" "$arrow" "$price_fmt" "$currency" "$change_fmt" "$change_abs")
        color=$(awk -v p="$change" 'BEGIN {
            if (p > 0.1)       print "#a6e3a1"
            else if (p < -0.1) print "#f38ba8"
            else               print "#f9e2af"
        }')

        [[ "$first" -eq 0 ]] && pos=$(( pos + sep_len ))
        seg_starts+=("$pos")
        seg_lens+=("${#text}")
        seg_texts+=("$text")
        seg_colors+=("$color")
        pos=$(( pos + ${#text} ))
        first=0
    done

    [[ ${#seg_texts[@]} -eq 0 ]] && exit 0

    loop_len=$(( pos + sep_len ))

    offset=0
    [[ -f "$SCROLL_FILE" ]] && offset=$(cat "$SCROLL_FILE")
    (( offset >= loop_len )) && offset=0
    printf '%d' $(( (offset + SCROLL_STEP) % loop_len )) > "$SCROLL_FILE"

    win_end=$(( offset + DISPLAY_WIDTH ))
    output=""
    n=${#seg_texts[@]}

    for copy in 0 1; do
        copy_off=$(( copy * loop_len ))
        for (( j=0; j<n; j++ )); do
            ss=$(( seg_starts[j] + copy_off ))
            se=$(( ss + seg_lens[j] ))
            ov_s=$(( ss > offset ? ss : offset ))
            ov_e=$(( se < win_end ? se : win_end ))
            if (( ov_s < ov_e )); then
                chunk="${seg_texts[j]:$(( ov_s - ss )):$(( ov_e - ov_s ))}"
                output+="<span color='${seg_colors[j]}'>$chunk</span>"
            fi
            ps=$se
            pe=$(( ps + sep_len ))
            ov_s=$(( ps > offset ? ps : offset ))
            ov_e=$(( pe < win_end ? pe : win_end ))
            if (( ov_s < ov_e )); then
                output+="${SEPARATOR:$(( ov_s - ps )):$(( ov_e - ov_s ))}"
            fi
        done
    done

    tooltip=$(build_tooltip)
    printf '{"text":"%s","tooltip":"%s","class":"neutral"}\n' "$output" "$tooltip"
else
    # Default: rotate one ticker per invocation
    i=0
    [[ -f "$STATE_FILE" ]] && i=$(cat "$STATE_FILE")
    sym="${TICKERS[$((i % ${#TICKERS[@]}))]}"
    printf '%d' $(( (i + 1) % ${#TICKERS[@]} )) > "$STATE_FILE"

    price=$(jq -r --arg s "$sym" '.[$s].price // empty' "$CACHE_FILE")
    change=$(jq -r --arg s "$sym" '.[$s].change // empty' "$CACHE_FILE")
    currency=$(jq -r --arg s "$sym" '.[$s].currency // empty' "$CACHE_FILE")
    [[ -z "$price" || -z "$change" ]] && exit 0

    css=$(awk -v p="$change" 'BEGIN { if (p > 0.1) print "up"; else if (p < -0.1) print "down"; else print "neutral" }')
    arrow=$(awk -v p="$change" 'BEGIN { if (p > 0.1) print "↑"; else if (p < -0.1) print "↓"; else print "→" }')
    price_fmt=$(awk -v p="$price" 'BEGIN { printf "%.2f", p }')
    change_fmt=$(awk -v c="$change" 'BEGIN { printf "%+.2f", c }')
    change_abs=$(awk -v c="$change" 'BEGIN { printf "%.2f", (c < 0 ? -c : c) }')

    text=$(render "$FORMAT" "$sym" "$arrow" "$price_fmt" "$currency" "$change_fmt" "$change_abs")
    tooltip=$(build_tooltip)

    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tooltip" "$css"
fi
