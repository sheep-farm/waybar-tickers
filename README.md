# waybar-tickers

Módulo Waybar para cotações rotativas via yfinance.

## Formato

```
AAPL ↑ 213.45
```

Sinais: `↑` alta, `→` neutro, `↓` baixa (limiar: ±0.1%).  
Classes CSS: `up`, `neutral`, `down` — estilizáveis via `style.css`.

## Instalação

```bash
pip install yfinance

cp tickers.py ~/.config/waybar/scripts/tickers.py
chmod +x ~/.config/waybar/scripts/tickers.py

cp tickers.txt ~/.config/waybar/scripts/tickers.txt
```

Adicionar ao `config.jsonc` (ver `waybar-config-snippet.jsonc`).

## tickers.txt

Um ticker por linha. Sufixo `.SA` para ações brasileiras. Linhas com `#` são ignoradas.

```
AAPL
PETR4.SA
BTC-USD
```

## Parâmetros (tickers.py)

| Variável | Padrão | Descrição |
|---|---|---|
| `DISPLAY_INTERVAL` | 3 s | Tempo por ticker |
| `REFRESH_INTERVAL` | 300 s | Intervalo de atualização dos dados |
