# breaker_fork v0.1.4 Porting Guide

This document describes the trading system in implementation-neutral terms so
the project can be loaded later and ported to another programming language.

## Project Files

- `breaker_fork.mq5`: visual indicator. It draws the same analysis that the EA
  uses for decisions.
- `breaker_fork_ea.mq5`: Expert Advisor. It includes the indicator logic plus
  order execution, risk sizing, loss-step money management, break even, magic
  number options, and account locking.
- Versioned files such as `breaker_fork_ea_v0.1.4.mq5` are immutable snapshots
  for testing and rollback.

## Execution Model

The EA is designed around closed candles.

1. On every tick, `OnTick()` calls `ManageBreakEven()` and then
   `ProcessClosedCandle()`.
2. `ProcessClosedCandle()` reads `iTime(_Symbol, _Period, 0)`.
3. If the current chart candle open time has not changed, no new signal scan is
   performed.
4. When a new chart candle appears, the previous candle is considered closed.
5. Market data is copied from shift `1`, excluding the current forming candle.
6. The EA can open a trade only when the signal candle equals the most recent
   closed candle.

Porting invariant: do not evaluate entries on forming candles.

## Time Window

Inputs:

- `InpStartHour`, `InpStartMinute`
- `InpEndHour`, `InpEndMinute`
- `InpTimeSource`

The session can cross midnight. A candle is inside the work window if its chart
time falls between start and end. End time is exclusive for normal activity,
while end boundary processing is preserved where the system evaluates the final
closed candle.

## Fresh Fractals

Fresh Fractals are Bill Williams fractals found before the start time.

Upper fractal:

- The candle high is greater than the highs of two candles on the left and two
  candles on the right.
- It remains fresh only if no later candle before the start cutoff closes above
  that fractal price.

Lower fractal:

- The candle low is lower than the lows of two candles on the left and two
  candles on the right.
- It remains fresh only if no later candle before the start cutoff closes below
  that fractal price.

The nearest Fresh Fractal is selected by time distance to the start time.

## Initial Direction

At/after start time:

- If a candle closes above the nearest upper Fresh Fractal, the direction becomes
  Buyer.
- If a candle closes below the nearest lower Fresh Fractal, the direction becomes
  Seller.
- If no upper Fresh Fractal exists before start, the system can create a default
  Buyer direction at the start candle.
- If no lower Fresh Fractal exists before start, the system can create a default
  Seller direction at the start candle.
- If both sides are missing, Buyer has priority to avoid simultaneous opposite
  directions.

## Reversal Direction

After an initial Buyer direction:

- Wait for a candle to close below the start candle low.
- Then wait for a close below the lower Fresh Fractal.
- That candle becomes a Seller reversal signal.

After an initial Seller direction:

- Wait for a candle to close above the start candle high.
- Then wait for a close above the upper Fresh Fractal.
- That candle becomes a Buyer reversal signal.

Previous signal arrows are kept; they are not deleted when a reversal appears.

## Dragon Phase One

Buyer direction:

- After becoming Buyer, find the first bearish candle.
- The candle before that first bearish candle is the Dragon candle.
- The bearish candle itself is the Mother Dragon candle.
- Phase One remains valid until a bearish candle closes below the Mother Dragon.
- If a candle closes above the Dragon high before Phase One is cancelled, enter
  Buy on that candle close.
- Buy stop uses the lowest low from candles after the Dragon candle through the
  entry candle.

Seller direction:

- After becoming Seller, find the first bullish candle.
- The candle before that first bullish candle is the Dragon candle.
- The bullish candle itself is the Mother Dragon candle.
- Phase One remains valid until a bullish candle closes above the Mother Dragon.
- If a candle closes below the Dragon low before Phase One is cancelled, enter
  Sell on that candle close.
- Sell stop uses the highest high from candles after the Dragon candle through
  the entry candle.

Important invariant: the stop candle is never the Dragon candle. Stops are
selected from candles after the Dragon candle.

## Dragon Phase Two

Buyer direction:

- Phase Two starts when Phase One is cancelled by a bearish close below the
  Mother Dragon.
- From the cancellation candle onward, the Master Candle is the bearish candle
  that makes the lowest low after the Dragon.
- If a later valid candle makes a lower low, it becomes the new Master Candle and
  confirmation count resets.
- Enter Buy after two bullish candles close above the Master Candle high.
- The two confirmation candles do not need to be consecutive.
- If any candle closes above the Dragon high while a Master Candle exists, cancel
  Master confirmation and enter Buy immediately.
- Buy stop is below the Master Candle.

Seller direction:

- Phase Two starts when Phase One is cancelled by a bullish close above the
  Mother Dragon.
- From the cancellation candle onward, the Master Candle is the bullish candle
  that makes the highest high after the Dragon.
- If a later valid candle makes a higher high, it becomes the new Master Candle
  and confirmation count resets.
- Enter Sell after two bearish candles close below the Master Candle low.
- The two confirmation candles do not need to be consecutive.
- If any candle closes below the Dragon low while a Master Candle exists, cancel
  Master confirmation and enter Sell immediately.
- Sell stop is above the Master Candle.

## Order Entry

Entry is a market order sent after the signal candle closes.

Buy:

- Entry reference is the signal candle close.
- Stop loss is below the selected stop candle low by `InpStopOffsetPips`.
- Take profit is `entry + riskDistance * InpTargetRiskReward`.

Sell:

- Entry reference is the signal candle close.
- Stop loss is above the selected stop candle high by `InpStopOffsetPips`.
- Take profit is `entry - riskDistance * InpTargetRiskReward`.

`InpStopOffsetPips` is converted to price distance by `PipSize()`.

## Lot Sizing

Base risk:

- `riskMoney = AccountBalance * InpRiskPercent / 100`
- `lossPerLot = (stopLossPriceDistance / tickSize) * tickValue`
- `lots = riskMoney / lossPerLot`

The result is clamped to symbol min/max volume and normalized to volume step.

## Loss-Step Money Management

Inputs:

- `InpEnableLossStepMoneyManagement`
- `InpLossStepHistoryDays`
- `InpFilterHistoryByMagicNumber`

Rules:

- History is read from MetaTrader closed deals.
- Only the current symbol is counted.
- If `InpFilterHistoryByMagicNumber` is true, only deals with
  `DEAL_MAGIC == InpMagicNumber` are counted.
- A losing SL close increments `ConsecutiveStopLosses`.
- A TP close resets `ConsecutiveStopLosses` to zero.
- Break-even SL closes with zero or positive net profit do not increment losses
  and do not reset the sequence.
- If `ConsecutiveStopLosses >= 3`, next trades use `0.5` lot multiplier.
- If `ConsecutiveStopLosses >= 4`, next trades use `0.25` lot multiplier.
- The multiplier stays reduced until a TP close resets the sequence.

## Break Even

Input:

- `InpBreakEvenMultiplier`

Buy:

- Initial risk distance is `openPrice - currentStopLoss`.
- If Bid moves at least `riskDistance * InpBreakEvenMultiplier`, move SL to
  `openPrice + currentSpread`.

Sell:

- Initial risk distance is `currentStopLoss - openPrice`.
- If Ask moves at least `riskDistance * InpBreakEvenMultiplier`, move SL to
  `openPrice - currentSpread`.

The code checks broker minimum stop distance before modifying the position.

## Magic Number Modes

Inputs:

- `InpUseMagicNumber`
- `InpMagicNumber`
- `InpFilterHistoryByMagicNumber`

Prop-style default:

- `InpUseMagicNumber = false`
- The EA does not call `SetExpertMagicNumber`.
- Order comments are controlled only by `InpTradeComment`.

Non-prop/testing mode:

- Set `InpUseMagicNumber = true`.
- The EA sets the configured magic number on new trades.
- Open position detection and Break Even only manage positions with that magic.
- If `InpFilterHistoryByMagicNumber = true`, loss-step history only uses closed
  deals with that magic.

## Account Lock

The account lock is not an input.

Code constant:

```mql5
const long BREAKER_ALLOWED_ACCOUNT_NUMBER = 0;
```

Rules:

- `0` means testing mode and allows any account.
- Any non-zero value must match `ACCOUNT_LOGIN`.
- If it does not match, the EA will not open new positions.

## Porting Checklist

When converting to another language, preserve these invariants:

- Closed-candle-only signal evaluation.
- Exclude the current forming candle from signal arrays.
- Keep all session comparisons based on chart candle time unless explicitly
  changing the time source.
- Do not allow signal arrows/trade entries outside the configured work window.
- Keep the Dragon candle out of stop candle selection.
- Reset Phase Two confirmation count when a new Master Candle is selected.
- Do not reset reduced lot size until a TP close occurs.
- Break-even SL should move beyond entry by spread, not exactly to entry.
- Account lock must remain a compiled/internal value, not a user input.

