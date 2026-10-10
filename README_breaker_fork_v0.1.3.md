# breaker_fork v0.1.3

MQL5 indicator and Expert Advisor fork based on `breaker v0.11.18`.

Current fork version: `v0.1.3`

## Versioning

Important milestones are stored in `versions/` with the format:

`breaker_fork_vMAJOR.MINOR.PATCH.mq5`

Expert Advisor builds use:

`breaker_fork_ea_vMAJOR.MINOR.PATCH.mq5`

Generated fork files include the fork version in their names:

- `breaker_fork_v0.1.3.mq5`
- `breaker_fork_ea_v0.1.3.mq5`
- `README_breaker_fork_v0.1.3.md`
- `CHANGELOG_breaker_fork_v0.1.3.md`

The unversioned `breaker_fork.mq5` and `breaker_fork_ea.mq5` files are only latest-test aliases for MetaTrader convenience.

## Terminology

- Start time: `InpStartHour` + `InpStartMinute`, default `16:30`.
- End time: `InpEndHour` + `InpEndMinute`, default `18:00`.
- Fresh Fractal: the unbroken pre-start-time fractals drawn by breaker.

## breaker_fork v0.1.3

- Removes the allowed account number from EA inputs.
- Adds `BREAKER_ALLOWED_ACCOUNT_NUMBER` near the top of the EA source code.
- Keeps `BREAKER_ALLOWED_ACCOUNT_NUMBER = 0` as testing mode, allowing any account.
- Any non-zero compiled account number must match `ACCOUNT_LOGIN`, otherwise the EA will not open positions.

## breaker_fork v0.1.2

- Reorders the first EA inputs to `InpRiskPercent`, `InpBreakEvenMultiplier`, `InpTargetRiskReward`, and `InpStopOffsetPips`.
- Renames the stop offset input from `InpStopBufferPoints` to `InpStopOffsetPips`.
- Converts stop offset pips to price distance through symbol digits before placing buy/sell stops.

## breaker_fork v0.1.1

- Adds optional Magic Number support back through `InpUseMagicNumber`.
- Keeps `InpUseMagicNumber = false` by default for prop-style runs with no custom magic number.
- Adds `InpMagicNumber`, default `110010`.
- Adds `InpFilterHistoryByMagicNumber`; when true, loss-step money management only counts closed history deals with `DEAL_MAGIC == InpMagicNumber`.
- When `InpUseMagicNumber` is true, open-position detection and Break Even management also match the configured Magic Number.
- Keeps `InpTradeComment`; an empty value sends an empty order comment.

## breaker_fork v0.1.0

- Starts a separate fork name and version series from `breaker v0.11.18`.
- Adds loss-step money management to the EA.
- After 3 losing SL closes in a row on the same symbol, the next trade uses half of the calculated risk lot.
- If the next trade also closes as a losing SL, later trades use one-quarter of the calculated risk lot.
- The risk lot only resets to the normal `InpRiskPercent` calculation after a TP close.
- Adds `InpEnableLossStepMoneyManagement` and `InpLossStepHistoryDays`.
- Moves Break Even beyond entry by current spread: buy SL moves above entry by spread, sell SL moves below entry by spread.
- Keeps Magic Number removed and keeps `InpTradeComment`; an empty value sends an empty order comment.

## Baseline breaker history

## v0.11.18

- Removes the EA-specific Magic Number input and does not set a custom magic number on trades.
- Adds `InpTradeComment`; an empty value sends an empty order comment.
- Removes EA chart status comments.

## v0.11.17

- Baseline history: added `InpAllowedAccountNumber` to the Expert Advisor as an account safety gate.
- `0` means testing mode and allows trading on any account.
- Any non-zero account number must match `ACCOUNT_LOGIN`, otherwise the EA will not open positions.

## v0.11.16

- Makes chart candle time the default time source for indicator and EA status/initialization.
- Uses the current chart bar time before falling back to server/local clock time.
- Keeps trading and fractal logic based on chart candle arrays, with no Dragon or fractal-rule changes from `v0.11.15`.

## v0.11.15

- Re-labels the active clean baseline from `v0.11.10` as `v0.11.15`.
- Keeps the `v0.11.10` logic unchanged so future work starts from a clean, unambiguous version.

## v0.11.10

- Prevents Buyer/Seller and reversal markers from being drawn outside the configured work window.
- Validates default start-time signals so they can only be placed inside the start/end window.
- Expands cleanup to remove old `breaker_ea_v...` objects as well as indicator objects.

## v0.11.9

- Adds default start-time direction when a Fresh Fractal side is missing.
- If no upper Fresh Fractal exists before start time, breaker creates a default Buyer signal on the start-time candle.
- If no lower Fresh Fractal exists before start time, breaker creates a default Seller signal on the start-time candle.
- If both Fresh Fractal sides are missing, Buyer has priority to avoid simultaneous opposite directions.

## v0.11.4

- Adds Phase 2 Dragon-break entry in both indicator and EA.
- Buyer phase: if a candle closes above the Dragon high while a Master Candle exists, Master confirmation is cancelled and that candle becomes the buy entry.
- Seller phase: if a candle closes below the Dragon low while a Master Candle exists, Master confirmation is cancelled and that candle becomes the sell entry.
- The stop candle remains the current Master Candle for this Dragon-break entry.

## v0.11.3

- Updates Phase 2 Master Candle selection in both indicator and EA.
- Buyer phase: any later candle with a lower low becomes the new Master Candle.
- Seller phase: any later candle with a higher high becomes the new Master Candle.
- Confirmation counts reset whenever a new Master Candle is selected.

## v0.11.2

- Fixes Phase 2 start timing in both indicator and EA.
- When Phase 1 is cancelled, the cancelling candle is now the first Phase 2 candle.
- This lets the cancelling candle become the Master Candle when it is the valid lowest-low or highest-high candle.
- Fixes end-time boundary processing so the candle that closes exactly at end time is still evaluated.
- With the default M5 window ending at `18:00`, the `17:55` candle can now produce its signal marker when its close arrives.
- Keeps the `v0.11.1` closed-candle-only EA scan behavior.

## v0.11.1

- Fixes a one-candle-late EA entry condition in phase checks.
- EA decision scans now copy market data from shift `1`, so the phase logic only sees fully closed candles.
- The current forming candle is still used only as the processing trigger, not as a signal candle.
- Keeps `v0.11.0` trading inputs and risk management unchanged.

## v0.11.0

- Adds the first Expert Advisor build: `breaker_ea_v0.11.0.mq5`.
- Opens trades from Dragon entry signals using the signal candle close as the entry reference.
- Buy stop loss is placed below the low of the stop candle.
- Sell stop loss is placed above the high of the stop candle.
- Adds configurable stop buffer with default `InpStopBufferPoints = 1`.
- Adds configurable target risk/reward with default `InpTargetRiskReward = 2.0`.
- Adds configurable risk percent with default `InpRiskPercent = 1.0`.
- Adds break-even management with default `InpBreakEvenMultiplier = 1.5`.
- Calculates lot size from account balance, risk percent, tick value, tick size, and volume limits.
- Keeps the indicator build intact; the EA is copied into `MQL5\\Experts\\breaker`.

## v0.10.1

- Fixes Phase 1 stop selection so the Dragon candle itself is never used as the stop candle.
- Stop search now starts from Mother Dragon, the first candle after Dragon, through the entry candle.

## v0.10.0

- Adds Dragon / Mother Dragon phase logic after Buyer or Seller signals.
- Phase 1 Buyer: first bearish candle after Buyer is Mother Dragon; previous candle is Dragon. A close above Dragon enters Buy with a black circle below the entry candle.
- Phase 1 Seller: first bullish candle after Seller is Mother Dragon; previous candle is Dragon. A close below Dragon enters Sell with a black circle above the entry candle.
- Phase 1 cancellation moves to Phase 2 when price closes beyond Mother Dragon against the active direction.
- Phase 2 Buyer: tracks the bearish Master Candle with the lowest low after Dragon and enters Buy after two bullish closes above Master Candle.
- Phase 2 Seller: tracks the bullish Master Candle with the highest high after Dragon and enters Sell after two bearish closes below Master Candle.
- Adds yellow stop circles on the candle that defines the stop.
- Restarts Dragon phase checks when the market direction changes.

## v0.9.0

- Corrects versioning for the latest reversal-rule update.
- Keeps the `v0.8.0` logic intact while publishing it under a new versioned build.

## v0.8.0

- Adds reversal signals while keeping earlier Buyer/Seller arrows.
- If the day starts with Seller, breaker waits for a candle to close above the start-time candle high, then waits for a later candle to break the upper Fresh Fractal and draws a new green Buyer arrow below it.
- If the day starts with Buyer, breaker waits for a candle to close below the start-time candle low, then waits for a later candle to break the lower Fresh Fractal and draws a new red Seller arrow above it.
- Reversal checks follow the active timeframe candle-close rule.

## v0.7.0

- Renames breaker's unbroken pre-start fractals to Fresh Fractals.
- Adds Buyer/Seller signals based on the Fresh Fractal closest in time to start time.
- Buyer: first candle after start time that closes above the nearest upper Fresh Fractal gets a green arrow below it.
- Seller: first candle after start time that closes below the nearest lower Fresh Fractal gets a red arrow above it.
- Keeps signal checks aligned to the active timeframe's candle close.

## v0.6.1

- Fixes duplicate fractal markers by drawing each fractal through only one layer.
- Uses chart objects for fractals when `InpDrawChartObjects` is enabled, otherwise uses indicator buffers.
- Reverses the visual triangle direction for upper and lower fractal markers.

## v0.6.0

- Adds `InpFractalLookbackDays`, default `20`.
- Shows valid pre-start-time fractals for the current day and previous configured days.
- Checks each day independently from that day's start until that day's start time.
- Keeps the candle-close update rule from `v0.5.0`.

## v0.5.0

- Adds the core update rule: indicator logic runs only when a new candle is formed on the current chart timeframe.
- Prevents tick-by-tick updates for status, time markers, and scan triggers.
- Uses the current bar open time as the candle-close update moment, so M5 updates once every 5 minutes, M15 once every 15 minutes, and so on.
- Updates chart status text to show the last candle-close update time.

## v0.4.1

- Shows the current available pre-start fractals immediately when the indicator is first loaded.
- Still performs the official daily pre-start fractal scan only once at the configured start time.
- Prevents duplicate start/end time markers by drawing each marker through one layer only.
- Stops deleting and rebuilding start/end time markers on every tick.
- Cleans old breaker chart objects from previous versions when the indicator loads.

## v0.4.0

- Runs the pre-start fractal scan only once per day, at the configured start time.
- Uses `InpStartHour` and `InpStartMinute` as the scan trigger time, not a hardcoded `16:30`.
- Keeps the scanned fractal markers on the chart after the one-time scan instead of recalculating them on every tick.
- Shows the daily fractal scan state in the chart status text.

## v0.3.1

- Compiles both `breaker.mq5` and the versioned `breaker_v0.3.1.mq5` file for MetaTrader testing.
- Adds chart objects for all time and fractal markers in addition to indicator buffers, making markers easier to see after reloads.
- Deletes breaker chart objects when the indicator is removed.

## v0.3.0

- Finds Bill Williams upper and lower fractals from the start of each day until the configured start time.
- Shows only upper fractals that have not been broken by a candle close above the fractal price before the start time.
- Shows only lower fractals that have not been broken by a candle close below the fractal price before the start time.
- Draws all valid fractals with orange triangle markers.

## v0.2.0

- Adds a circle below the candle that contains the configured start time.
- Adds a circle below the candle that contains the configured end time.
- Adds marker color, size, offset, and visibility inputs.

## v0.1.0

- Adds configurable start hour/minute.
- Adds configurable end hour/minute.
- Runs future breaker logic only inside the configured time window.
- Supports broker server time or local computer time.
- Shows a small status text on the chart.

Default work window:

`16:30` to `18:00`

The end time is exclusive, so the indicator is active until `17:59` and stops at `18:00`.
