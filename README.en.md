# breaker_mfe — MetaTrader 5

English | [فارسی](README.md)

An **MQL5** indicator and Expert Advisor for displaying and trading **Fresh Fractal / Dragon** setups within a configurable session. The project uses the source name `breaker_mfe` and is forked from `breaker v0.11.18`. The original project also belonged to the same creator. This version adds risk-based position sizing, reduced volume after losing stop-loss exits, and break-even management.

**Latest version in this folder: `v0.1.6`** · Documentation checked against source: `2026-10-11`

## Project components

| Component | Current source | Purpose |
| --- | --- | --- |
| Indicator | [breaker_mfe_v0.1.6.mq5](breaker_mfe_v0.1.6.mq5) | Displays session times, fractals, direction, reversals, entries, and stop candles; does not place orders |
| Expert Advisor | [breaker_mfe_ea_v0.1.6.mq5](breaker_mfe_ea_v0.1.6.mq5) | Includes analysis, market orders, position sizing, and stop management |

The EA contains its own analysis logic and does not require a separate indicator installation or call. Both components use the current chart's symbol and timeframe.

## Features

- Configurable trading session, defaulting to `16:30–18:00` in chart candle time.
- Five-candle Bill Williams fractals, with levels broken before the session removed from the fresh set.
- Initial `Buyer` or `Seller` direction and a reversal check within the session.
- Two Dragon entry phases, with the stop reference candle marked on the chart.
- EA signal evaluation on closed candles, excluding the forming candle from analysis arrays.
- Position sizing based on a percentage of account **Balance** and stop distance.
- Reduced volume after losing SL exits, restored to base sizing after a TP exit.
- Stop movement beyond entry by the current spread.
- Optional Magic Number, an independent history filter, and an account restriction compiled into the code.

## Installation and quick start

### Requirements

- MetaTrader 5 and MetaEditor with MQL5 compilation support.
- Historical data for the selected symbol and timeframe.
- Algorithmic trading permission in both the terminal and EA settings to trade with the EA.

The EA uses the standard `Trade/Trade.mqh` library. The current code has no Python, DLL, external API, or API-key dependency. The `.mq5` files target MetaTrader 5.

### Steps

1. Download the project files from GitHub.
2. In MetaTrader 5, select **File → Open Data Folder** to open that terminal's data directory.
3. Copy `breaker_mfe_v0.1.6.mq5` to `MQL5/Indicators/breaker_mfe/`.
4. Copy `breaker_mfe_ea_v0.1.6.mq5` to `MQL5/Experts/breaker_mfe/`. Create the `breaker_mfe` subfolders if needed.
5. Open each source in MetaEditor and use **F7 / Compile**. Compilation produces an `.ex5` file.
6. Refresh the terminal's Navigator and attach the desired component to your selected symbol and timeframe chart.
7. For the EA, review session times, risk parameters, and Magic Number settings, then enable Algo Trading permission.

Use the indicator for visual analysis only. In the EA, `InpEnableTrading=false` disables order placement and break-even management while analysis and drawing can continue.

## System logic

### 1. Session timing and closed candles

The start is inclusive and the end is exclusive for candle opening times. For example, on M5 with an `18:00` end, the `17:55` candle can still be evaluated when it closes at `18:00`.

In `OnTick()`, the EA checks break-even management first, then scans signals only when a new candle appears. Data is copied from `shift=1`. An order is eligible only when the signal belongs to the most recently closed candle. The first scan after loading initializes the engine and does not place historical orders.

Align the session with **the chart's own clock**. `InpTimeSource` does not convert candle timezones: `BreakerNow()` prioritizes chart candle time whenever available, falling back to local or server time only when it is unavailable.

### 2. Fresh Fractals and initial direction

- **Upper Fractal:** the center candle's high exceeds the highs of the two preceding and two following candles.
- **Lower Fractal:** the center candle's low is below the lows of the two preceding and two following candles.
- An upper fractal remains fresh if no later candle before the session start closes above its level. A lower fractal remains fresh if no such candle closes below it.
- The upper and lower Fresh Fractals closest in time to session start are selected.
- A close above the upper level creates Buyer direction; a close below the lower level creates Seller direction.
- A missing upper fractal can create a default Buyer signal on the start candle. A missing lower fractal can create a default Seller signal. Buyer takes priority when both are missing.

A direction arrow alone is not an order instruction. Entries come from Dragon logic.

### 3. Direction reversal

After Buyer, the system waits for a close below the session-start candle's low, followed by a close below the Lower Fresh Fractal on a **later candle**, to create Seller direction. After Seller, the rules are reversed: a close above the start candle's high, followed on a later candle by a break above the Upper Fresh Fractal.

The required opposite Fresh Fractal must exist. Previous arrows remain visible after a reversal, and Dragon logic is evaluated again for the new direction segment.

### 4. Dragon phase one

| Rule | Buyer | Seller |
| --- | --- | --- |
| Mother Dragon | First bearish candle after the direction signal | First bullish candle after the direction signal |
| Dragon | Candle immediately before Mother Dragon | Candle immediately before Mother Dragon |
| Entry | Close above Dragon high | Close below Dragon low |
| Phase cancellation | A bearish candle closes below Mother Dragon low | A bullish candle closes above Mother Dragon high |
| Stop candle | Lowest low from Mother Dragon through the entry candle | Highest high from Mother Dragon through the entry candle |

The Dragon candle itself is excluded from phase-one stop selection. The cancellation candle starts phase two.

### 5. Dragon phase two

- For Buyer, the first phase-two candle becomes Master. Any later candle with a lower low replaces it and resets the confirmation count.
- Two bullish candles closing above Master high create a Buy entry; they do not have to be consecutive.
- A close above Dragon high while a Master exists also creates an immediate Buy entry.
- For Seller, Master is replaced when a candle makes a higher high. Two bearish closes below Master low, or a close below Dragon low, create a Sell entry.
- The phase-two stop uses Master's low or high.

In the current implementation, replacing Master is not restricted by candle color. Any candle making the required new extreme can become Master.

## Orders, position sizing, and risk management

### Entry, stop loss, and take profit

The EA sends a **market order** after the signal candle closes:

| Direction | Stop Loss | Take Profit |
| --- | --- | --- |
| Buy | Stop candle low minus offset | Signal close + risk distance × RR |
| Sell | Stop candle high plus offset | Signal close − risk distance × RR |

Volume and TP calculations use the signal candle's closing price. The actual market fill can differ, so actual trade risk and RR may differ from the calculated values.

`InpStopOffsetPips` is converted to a price distance by `PipSize()`: one pip equals `10 × _Point` for symbols with 3 or 5 digits, and `_Point` otherwise. The same code convention applies to non-forex symbols.

### Position sizing

```text
riskMoney  = AccountBalance × InpRiskPercent / 100
lossPerLot = (stopDistance / tickSize) × tickValue
rawLots    = (riskMoney / lossPerLot) × lossStepMultiplier
```

Volume is limited by the broker's minimum and maximum, with decimal precision derived from `SYMBOL_VOLUME_STEP`. The current code rounds volume using `NormalizeDouble`; volume validity for unusual step sizes needs checking in the broker environment.

**Main v0.1.6 change:** `InpSkipTradeIfLotBelowMinimum=false` is the default. If calculated volume is below the broker minimum, it is raised to that minimum. Actual risk can therefore exceed the configured percentage. Set the option to `true` to skip such trades.

### Loss-step money management

The EA checks closed deals for the current symbol within `InpLossStepHistoryDays`:

| Losing SL exits since the latest TP in selected history | Base-volume multiplier |
| --- | --- |
| 0–2 | `1.0` |
| 3 | `0.5` |
| 4 or more | `0.25` |

A TP exit resets the counter. An SL exit counts only if that deal's Profit + Swap + Commission is negative. Non-losing SL exits and manual exits do not reset it. Counting is based on **deals**, which does not necessarily equal the number of fully closed positions.

### Break even

With the default settings, after a favorable move of `1.5` times the distance from the actual opening price to the current SL:

- Buy: SL moves to `openPrice + currentSpread`.
- Sell: SL moves to `openPrice − currentSpread`.

The broker's minimum stop distance is checked before modification. Break-even management runs on every tick and is not limited by session end. Moving the stop by the spread does not guarantee net profit after costs or execution slippage.

## Key settings

### Trading and account — EA only

| Input | Default | Meaning |
| --- | --- | --- |
| `InpRiskPercent` | `1.0` | Percentage of Balance used for base sizing |
| `InpBreakEvenMultiplier` | `1.5` | Stop-movement threshold in risk-distance units |
| `InpTargetRiskReward` | `2.0` | TP multiplier relative to risk distance |
| `InpStopOffsetPips` | `1.0` | Extra stop distance beyond the selected candle |
| `InpSkipTradeIfLotBelowMinimum` | `false` | Skip below-minimum volume when enabled |
| `InpEnableTrading` | `true` | Enable orders and break-even management |
| `InpEnableLossStepMoneyManagement` | `true` | Enable loss-step volume reduction |
| `InpLossStepHistoryDays` | `3650` | Deal-history lookback in days |
| `InpMaxBarsToScan` | `5000` | Maximum number of candles copied for EA scanning |
| `InpOnePositionPerSymbol` | `true` | Block entry when a matching position exists |
| `InpUseMagicNumber` | `false` | Apply Magic to orders and position selection |
| `InpMagicNumber` | `110010` | Configured Magic identifier |
| `InpFilterHistoryByMagicNumber` | `false` | Limit history to the configured Magic |
| `InpTradeComment` | Empty string | Order comment |

### Session and display — shared

| Input | Default | Meaning |
| --- | --- | --- |
| `InpStartHour` / `InpStartMinute` | `16` / `30` | Session start |
| `InpEndHour` / `InpEndMinute` | `18` / `0` | Session end |
| `InpTimeSource` | `BREAKER_TIME_CHART` | Chart-time priority; no timezone conversion |
| `InpFractalLookbackDays` | `20` | Fractal lookback in days |
| `InpShowTimeMarkers` | `true` | Session time markers |
| `InpShowUnbrokenFractals` | `true` | Display valid fractals |
| `InpShowFreshFractalSignals` | `true` | Enable initial-direction processing |
| `InpShowFreshFractalReversals` | `true` | Enable reversal processing |
| `InpShowDragonPhases` | `true` | Enable Dragon phase processing |
| `InpDrawChartObjects` | `true` | Draw using chart objects |

Marker colors, sizes, and offsets are configurable. The indicator also has `InpShowStatusOnChart=true`; the current EA does not write chart status text.

**Execution detail:** disabling `InpShowFreshFractalSignals` or `InpShowDragonPhases` in the EA stops the entry-generation path. Disabling `InpShowFreshFractalReversals` disables reversal logic. These three options affect execution, not just appearance.

### Magic Number and position-management scope

With `InpUseMagicNumber=false`, position selection for entry blocking and break-even management uses only the symbol. Manual positions or other EAs' positions on the same symbol can fall within that scope.

With `InpUseMagicNumber=true`, new orders receive the configured Magic and position selection is restricted to it. History filtering is independent: also enable `InpFilterHistoryByMagicNumber=true` to restrict loss-step history to that identifier. Different identifiers can be used for independent EA instances.

### Account restriction

The EA source declares this constant near the top:

```mql5
const long BREAKER_ALLOWED_ACCOUNT_NUMBER = 0;
```

`0` allows entries on any account. A nonzero value must match `ACCOUNT_LOGIN`; otherwise, no new orders are placed. This is not a settings-panel input and changing it requires recompilation. In the current code, this restriction does not prevent break-even management of existing positions.

## Chart markers

| Default marker | Meaning |
| --- | --- |
| Green / red time circle | Session start / end |
| Orange triangle | Upper or lower Fresh Fractal |
| Green / red arrow | Buyer / Seller direction or reversal |
| Black circle | Dragon entry signal candle |
| Yellow circle | Stop reference candle |

An entry marker does not guarantee an executed order. Account restrictions, trading permission, an existing position, volume limits, or broker rejection can prevent execution. You can change the entry-circle color on dark chart backgrounds.

## Checking behavior and troubleshooting

Evaluate the EA in Strategy Tester using a specified symbol, timeframe, and date range. Visual mode helps compare markers with trades; real-tick modeling is useful for tick-dependent behavior such as break-even management. Record results alongside spread, costs, symbol specifications, and Inputs.

| Situation | Check |
| --- | --- |
| Component missing from Navigator | Terminal data directory, Indicators/Experts path, compilation output, and Refresh |
| Invalid input parameters | Valid times, different start/end, positive risk/RR/BE, nonnegative offset, and `InpMaxBarsToScan >= 100` |
| Marker appears but no trade opens | Algo Trading, `InpEnableTrading`, account restriction, matching positions, minimum volume, and Experts/Journal messages |
| No reversal trade | Opposite Fresh Fractal exists and `InpShowFreshFractalReversals` is enabled |
| Break even does not activate | Trading permission, valid SL, movement threshold, broker stop distance, and Magic scope |
| Unexpected session times | Chart candle clock and session settings; Time Source does not convert timezones |

## Current status and limitations

- This README was prepared from `v0.1.6` source. No new compilation, live run, or backtest was performed while preparing the documentation.
- The EA declares `InpEnableMfeMaeReport`, `InpMfeMaeConservativeSameBar`, and an MFE/MAE record structure, but the current code does not connect them to recording, calculation, or report output. They are not a finished reporting feature.
- Time helpers recognize sessions crossing midnight, but daily scanning depends on the current calendar date. Complete overnight-session behavior was not verified during documentation.
- The EA does not implement explicit return-code checks or retries for `Buy`, `Sell`, or `PositionModify`. Check execution results in the terminal.
- Limited historical data and broker volume/stop constraints can change actual behavior. No verified profitability results or performance metrics accompany this version.

## Files and versioning

```text
breaker_mfe/
├── README.md                         # Persian guide for the current version
├── README.en.md                      # English guide for the current version
├── breaker_mfe_v0.1.6.mq5            # Current indicator source
└── breaker_mfe_ea_v0.1.6.mq5         # Current EA source
```

This repository provides only the `v0.1.6` sources and the Persian and English READMEs for that version.

Read the project version from filenames and the `BREAKER_VERSION` constant. The current source's `#property version` is `1.000`, which does not identify the project release version.

## Development

When changing logic, review the indicator and EA together. Preserve closed-candle evaluation, the reversal-confirmation sequence, stop-candle selection, and Master confirmation resets. The selected version's source is the reference for runtime behavior.

For bug reports, include the source version, symbol, timeframe, Inputs, event time on the chart, and relevant Experts/Journal output. Remove confidential account information.

## License

The current project files do not include a `LICENSE` file. The owner needs to specify publication and usage terms; this README does not assign a new license to the code.

## Author's note

Ever since I uploaded the file to AI, it hasn't worked.

Developed by M.H.B
