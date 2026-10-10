# breaker_fork changelog v0.1.0

## breaker_fork v0.1.0

- Started a separate fork name and version series from `breaker v0.11.18`.
- Added loss-step money management to the EA.
- After 3 losing SL closes in a row on the same symbol, the next trade uses half of the calculated risk lot.
- If that reduced trade also closes as a losing SL, later trades use one-quarter of the calculated risk lot.
- Risk resets to the normal `InpRiskPercent` lot only after a TP close.
- Added `InpEnableLossStepMoneyManagement` and `InpLossStepHistoryDays`.
- Changed Break Even so buy SL moves above entry by current spread and sell SL moves below entry by current spread.
- Kept Magic Number removed and kept `InpTradeComment`; empty input keeps order comments empty.

## Baseline breaker history

## v0.11.18

- Removed the EA-specific Magic Number input and stopped setting a custom magic number through `CTrade`.
- Added `InpTradeComment`; leave it empty to keep order comments empty.
- Removed EA chart status comments.

## v0.11.17

- Added `InpAllowedAccountNumber` to the EA.
- Allows positions when `InpAllowedAccountNumber = 0` for testing.
- Blocks new positions when a non-zero allowed account does not match `ACCOUNT_LOGIN`.

## v0.11.16

- Made chart candle time the default time source.
- Updated `BreakerNow()` to use the current chart bar time before falling back to server/local clock time.
- No Dragon, Fresh Fractal, entry, stop, or trading-rule changes from `v0.11.15`.

## v0.11.15

- Re-labeled the active clean baseline from `v0.11.10` as `v0.11.15`.
- No trading-logic changes from `v0.11.10`.

## v0.11.10

- Blocked Buyer/Seller signal markers outside the configured work window.
- Blocked reversal markers outside the configured work window.
- Added a time-window guard for default start-time direction signals.
- Expanded object cleanup to remove old EA marker objects.

## v0.11.9

- Added default start-time Buyer/Seller direction when one Fresh Fractal side is missing.
- Missing upper Fresh Fractal creates a default Buyer signal on the start-time candle.
- Missing lower Fresh Fractal creates a default Seller signal on the start-time candle.
- Buyer takes priority when both sides are missing.

## v0.11.4

- Added Phase 2 Dragon-break entry in both indicator and EA.
- Buyer phase now enters immediately when a candle closes above the Dragon high after a Master Candle exists.
- Seller phase now enters immediately when a candle closes below the Dragon low after a Master Candle exists.
- The Dragon-break entry uses the current Master Candle as its stop candle.

## v0.11.3

- Updated Phase 2 Master Candle selection in both indicator and EA.
- Buyer phase now promotes any candle with a lower low to the new Master Candle.
- Seller phase now promotes any candle with a higher high to the new Master Candle.
- Reset Phase 2 confirmation count whenever the Master Candle changes.

## v0.11.2

- Fixed Phase 2 start timing in both indicator and EA.
- The candle that cancels Phase 1 is now included as the first Phase 2 candle.
- The cancelling candle can now become the Master Candle when it makes the valid Phase 2 low/high.
- Fixed end-time boundary processing so the candle that closes exactly at end time is still evaluated.
- Preserved the `v0.11.1` closed-candle-only EA scan behavior.

## v0.11.1

- Fixed EA phase scans so they only use fully closed candles.
- Changed copied market data for EA decisions to start from shift `1`, excluding the current forming candle.
- Kept trade execution gated to the most recent closed signal candle.
- Preserved all `v0.11.0` trading inputs and risk settings.

## v0.11.0

- Added `breaker_ea_v0.11.0.mq5` as the first Expert Advisor build.
- Added market trade execution from Dragon entry signals.
- Added risk-based lot sizing with configurable risk percent.
- Added configurable stop buffer for SL placement below/above the stop candle.
- Added configurable target risk/reward and break-even multiplier.
- Added break-even stop movement after configured R multiple.
- Copied and compiled the EA under MetaTrader `MQL5\\Experts\\breaker`.

## v0.10.1

- Fixed Phase 1 stop range to exclude the Dragon candle.
- Phase 1 stop now uses only candles after Dragon through the entry candle.

## v0.10.0

- Added Dragon and Mother Dragon detection after Buyer/Seller direction signals.
- Added Phase 1 entry logic with black entry circles.
- Added Phase 2 Master Candle logic with non-consecutive two-candle confirmation.
- Added yellow stop circles for the candle defining stop placement.
- Added reset of Dragon phase checks after direction changes.

## v0.9.0

- Corrected the latest update into a new versioned build instead of reusing `v0.8.0`.
- Updated code version constants, documents, desktop copy, and MetaTrader copy to `v0.9.0`.

## v0.8.0

- Added post-signal reversal logic without deleting earlier signal arrows.
- Added Seller-to-Buyer reversal after close above the start-time candle high and then upper Fresh Fractal break.
- Added Buyer-to-Seller reversal after close below the start-time candle low and then lower Fresh Fractal break.
- Added separate reversal buffers and chart-object suffixes.

## v0.7.0

- Named unbroken pre-start fractals Fresh Fractals.
- Added Buyer/Seller signal markers from nearest Fresh Fractals to start time.
- Added green Buyer arrows below signal candles.
- Added red Seller arrows above signal candles.
- Kept prior Fresh Fractal drawing and lookback behavior intact.

## v0.6.1

- Fixed duplicated fractal markers caused by drawing both chart objects and buffers.
- Reversed upper/lower fractal triangle direction visually.

## v0.6.0

- Added configurable fractal lookback days with `InpFractalLookbackDays`.
- Defaulted fractal lookback to 20 days.
- Extended pre-start fractal display across multiple prior days.
- Documented start time and end time terminology.

## v0.5.0

- Added candle-close gating for all indicator updates.
- Stopped processing repeated `OnCalculate` calls inside the same still-forming candle.
- Aligned update timing with the active chart timeframe.
- Changed status text from tick time to last candle-close update time.

## v0.4.1

- Added initial fractal preview on indicator load.
- Kept the final pre-start fractal scan limited to one run per day at the configured start time.
- Fixed duplicate start/end markers caused by drawing both buffers and chart objects.
- Changed time marker drawing so it is initialized once instead of rebuilt every tick.
- Added cleanup for old breaker marker objects from previous versions.

## v0.4.0

- Changed unbroken-fractal analysis to run once per day at the configured start time.
- Stopped recalculating pre-start fractals on every tick.
- Preserved the one-time scan result on the chart after the trigger.
- Added chart status text for the daily scan state.

## v0.3.1

- Added chart-object drawing for start/end circles and valid fractal triangles.
- Kept indicator buffer drawing as a backup data/plot layer.
- Compiled both the latest alias and versioned indicator files in MetaTrader folders.

## v0.3.0

- Added Bill Williams fractal detection before the configured start time.
- Added upper fractal filtering: hide it if a later candle closes above it before the start time.
- Added lower fractal filtering: hide it if a later candle closes below it before the start time.
- Added orange triangle markers for both upper and lower valid fractals.

## v0.2.0

- Added start/end time circles below candles.
- Added inputs for marker visibility, color, size, and offset.
- Added version numbers to generated file names and document titles.

## v0.1.0

- Created the first breaker MQL5 indicator.
- Added configurable working time window inputs.
- Added validation for hour/minute inputs.
- Added server/local time source selection.
- Added chart status output.
