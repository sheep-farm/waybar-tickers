# waybar-tickers

Módulo Waybar para cotações rotativas via Yahoo Finance (sem dependências externas).

## Formato

```
AAPL ↓ 301.54 USD -1.89%
PETR4.SA ↑ 41.22 BRL +0.81%
BTC-USD ↑ 63725.70 USD +0.77%
```

Sinais: `↑` alta, `→` neutro, `↓` baixa (limiar: ±0.1%).  
Classes CSS: `up`, `neutral`, `down` — estilizáveis via `style.css`.

## Dependências

`curl` e `jq` — disponíveis na maioria das distros.

## Instalação

```bash
cp tickers.sh ~/.config/waybar/scripts/tickers.sh
chmod +x ~/.config/waybar/scripts/tickers.sh

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

## Parâmetros (tickers.sh)

| Variável | Padrão | Descrição |
|---|---|---|
| `REFRESH_INTERVAL` | 300 s | Intervalo de atualização dos dados |

O intervalo de exibição por ticker é controlado pelo `interval` no `config.jsonc` (padrão: 3 s).
