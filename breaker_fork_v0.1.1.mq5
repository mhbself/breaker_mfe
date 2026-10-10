#property copyright "breaker_fork"
#property link      ""
#property version   "1.000"
#property indicator_chart_window
#property indicator_plots 8
#property indicator_buffers 8

#property indicator_label1 "Start time"
#property indicator_type1 DRAW_ARROW
#property indicator_color1 clrLimeGreen
#property indicator_width1 2

#property indicator_label2 "End time"
#property indicator_type2 DRAW_ARROW
#property indicator_color2 clrTomato
#property indicator_width2 2

#property indicator_label3 "Upper Fresh Fractal"
#property indicator_type3 DRAW_ARROW
#property indicator_color3 clrOrange
#property indicator_width3 2

#property indicator_label4 "Lower Fresh Fractal"
#property indicator_type4 DRAW_ARROW
#property indicator_color4 clrOrange
#property indicator_width4 2

#property indicator_label5 "Buyer signal"
#property indicator_type5 DRAW_ARROW
#property indicator_color5 clrLimeGreen
#property indicator_width5 2

#property indicator_label6 "Seller signal"
#property indicator_type6 DRAW_ARROW
#property indicator_color6 clrRed
#property indicator_width6 2

#property indicator_label7 "Buyer reversal"
#property indicator_type7 DRAW_ARROW
#property indicator_color7 clrLimeGreen
#property indicator_width7 2

#property indicator_label8 "Seller reversal"
#property indicator_type8 DRAW_ARROW
#property indicator_color8 clrRed
#property indicator_width8 2

enum ENUM_BREAKER_TIME_SOURCE
{
   BREAKER_TIME_CHART  = 0,
   BREAKER_TIME_SERVER = 1,
   BREAKER_TIME_LOCAL  = 2
};

input int InpStartHour = 16;
input int InpStartMinute = 30;
input int InpEndHour = 18;
input int InpEndMinute = 0;
input ENUM_BREAKER_TIME_SOURCE InpTimeSource = BREAKER_TIME_CHART;
input bool InpShowStatusOnChart = true;
input bool InpShowTimeMarkers = true;
input color InpStartMarkerColor = clrLimeGreen;
input color InpEndMarkerColor = clrTomato;
input int InpMarkerOffsetPoints = 30;
input int InpMarkerSize = 2;
input bool InpShowUnbrokenFractals = true;
input int InpFractalLookbackDays = 20;
input color InpFractalMarkerColor = clrOrange;
input int InpFractalMarkerOffsetPoints = 20;
input int InpFractalMarkerSize = 2;
input bool InpShowFreshFractalSignals = true;
input color InpBuyerSignalColor = clrLimeGreen;
input color InpSellerSignalColor = clrRed;
input int InpSignalMarkerOffsetPoints = 40;
input int InpSignalMarkerSize = 2;
input bool InpShowFreshFractalReversals = true;
input bool InpShowDragonPhases = true;
input color InpEntryCircleColor = clrBlack;
input color InpStopCircleColor = clrYellow;
input int InpDragonMarkerOffsetPoints = 55;
input int InpDragonMarkerSize = 2;
input bool InpDrawChartObjects = true;

const string BREAKER_VERSION = "breaker_fork v0.1.1";
const string BREAKER_OBJECT_PREFIX = "breaker_fork_v0_1_1_";
const int BREAKER_MARKER_ARROW = 159;
const int BREAKER_UP_TRIANGLE = 217;
const int BREAKER_DOWN_TRIANGLE = 218;
const int BREAKER_BUY_ARROW = 233;
const int BREAKER_SELL_ARROW = 234;

double StartMarkerBuffer[];
double EndMarkerBuffer[];
double UpperFractalBuffer[];
double LowerFractalBuffer[];
double BuyerSignalBuffer[];
double SellerSignalBuffer[];
double BuyerReversalBuffer[];
double SellerReversalBuffer[];

datetime LastFractalScanDay = 0;
bool FractalBuffersInitialized = false;
bool TimeMarkersInitialized = false;
datetime LastProcessedBarOpen = 0;

int MinutesOfDay(const int hour, const int minute)
{
   return hour * 60 + minute;
}

bool IsValidClock(const int hour, const int minute)
{
   return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
}

bool InputsAreValid()
{
   if(!IsValidClock(InpStartHour, InpStartMinute))
      return false;

   if(!IsValidClock(InpEndHour, InpEndMinute))
      return false;

   if(InpFractalLookbackDays < 1)
      return false;

   return MinutesOfDay(InpStartHour, InpStartMinute) != MinutesOfDay(InpEndHour, InpEndMinute);
}

string FormatClock(const int hour, const int minute)
{
   return StringFormat("%02d:%02d", hour, minute);
}

datetime BreakerNow()
{
   const datetime chartBarTime = iTime(_Symbol, _Period, 0);
   if(chartBarTime > 0)
      return chartBarTime;

   if(InpTimeSource == BREAKER_TIME_LOCAL)
      return TimeLocal();

   return TimeCurrent();
}

bool IsWithinWorkingTime(const datetime moment)
{
   MqlDateTime parts;
   TimeToStruct(moment, parts);

   const int currentMinute = MinutesOfDay(parts.hour, parts.min);
   const int startMinute = MinutesOfDay(InpStartHour, InpStartMinute);
   const int endMinute = MinutesOfDay(InpEndHour, InpEndMinute);

   if(startMinute < endMinute)
      return currentMinute >= startMinute && currentMinute < endMinute;

   return currentMinute >= startMinute || currentMinute < endMinute;
}

bool BreakerIsActiveNow()
{
   return IsWithinWorkingTime(BreakerNow());
}

datetime ClockOnDate(const datetime baseTime, const int hour, const int minute)
{
   MqlDateTime parts;
   TimeToStruct(baseTime, parts);
   parts.hour = hour;
   parts.min = minute;
   parts.sec = 0;
   return StructToTime(parts);
}

datetime DayStart(const datetime baseTime)
{
   MqlDateTime parts;
   TimeToStruct(baseTime, parts);
   parts.hour = 0;
   parts.min = 0;
   parts.sec = 0;
   return StructToTime(parts);
}

int SafePeriodSeconds()
{
   const int seconds = PeriodSeconds(_Period);
   if(seconds > 0)
      return seconds;

   return 60;
}

bool TimeFallsInsideBar(const datetime targetTime, const datetime barOpen, const datetime nextBarOpen)
{
   return targetTime >= barOpen && targetTime < nextBarOpen;
}

datetime CurrentBarOpen(const int ratesTotal, const bool series, const datetime &time[])
{
   if(ratesTotal <= 0)
      return 0;

   if(series)
      return time[0];

   return time[ratesTotal - 1];
}

bool ShouldProcessClosedCandle(const datetime currentBarOpen, const int prevCalculated)
{
   if(currentBarOpen == 0)
      return false;

   if(prevCalculated == 0)
      return true;

   return currentBarOpen != LastProcessedBarOpen;
}

void DeleteBreakerObjects()
{
   const int total = ObjectsTotal(0, 0, -1);

   for(int i = total - 1; i >= 0; i--)
   {
      const string name = ObjectName(0, i, 0, -1);

      if(StringFind(name, "breaker_v") == 0
         || StringFind(name, "breaker_ea_v") == 0)
         ObjectDelete(0, name);
   }
}

void DeleteBreakerObjectsBySuffix(const string suffix)
{
   const string objectPrefix = BREAKER_OBJECT_PREFIX + suffix + "_";
   const int total = ObjectsTotal(0, 0, -1);

   for(int i = total - 1; i >= 0; i--)
   {
      const string name = ObjectName(0, i, 0, -1);

      if(StringFind(name, objectPrefix) == 0)
         ObjectDelete(0, name);
   }
}

void DrawMarkerObject(
   const string suffix,
   const datetime markerTime,
   const double markerPrice,
   const int arrowCode,
   const color markerColor,
   const int markerSize
)
{
   if(!InpDrawChartObjects)
      return;

   const string name = BREAKER_OBJECT_PREFIX + suffix + "_" + IntegerToString((long)markerTime);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_ARROW, 0, markerTime, markerPrice);
   else
      ObjectMove(0, name, 0, markerTime, markerPrice);

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, markerColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, markerSize);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

bool HasTwoFractalSides(const int index, const int ratesTotal, const bool series)
{
   if(series)
      return index >= 2 && index + 2 < ratesTotal;

   return index >= 2 && index + 2 < ratesTotal;
}

bool IsUpperBillWilliamsFractal(
   const int index,
   const int ratesTotal,
   const bool series,
   const double &high[]
)
{
   if(!HasTwoFractalSides(index, ratesTotal, series))
      return false;

   const double fractalHigh = high[index];

   return fractalHigh > high[index - 1]
      && fractalHigh > high[index - 2]
      && fractalHigh > high[index + 1]
      && fractalHigh > high[index + 2];
}

bool IsLowerBillWilliamsFractal(
   const int index,
   const int ratesTotal,
   const bool series,
   const double &low[]
)
{
   if(!HasTwoFractalSides(index, ratesTotal, series))
      return false;

   const double fractalLow = low[index];

   return fractalLow < low[index - 1]
      && fractalLow < low[index - 2]
      && fractalLow < low[index + 1]
      && fractalLow < low[index + 2];
}

bool HasCloseAbove(
   const datetime fractalTime,
   const datetime dayStart,
   const datetime cutoffTime,
   const double fractalPrice,
   const int ratesTotal,
   const datetime &time[],
   const double &close[]
)
{
   for(int i = 0; i < ratesTotal; i++)
   {
      if(time[i] <= fractalTime || time[i] < dayStart || time[i] >= cutoffTime)
         continue;

      if(close[i] > fractalPrice)
         return true;
   }

   return false;
}

bool HasCloseBelow(
   const datetime fractalTime,
   const datetime dayStart,
   const datetime cutoffTime,
   const double fractalPrice,
   const int ratesTotal,
   const datetime &time[],
   const double &close[]
)
{
   for(int i = 0; i < ratesTotal; i++)
   {
      if(time[i] <= fractalTime || time[i] < dayStart || time[i] >= cutoffTime)
         continue;

      if(close[i] < fractalPrice)
         return true;
   }

   return false;
}

bool FractalScanIsDue(const datetime now, datetime &scanDayStart, datetime &scanStartTime)
{
   scanDayStart = DayStart(now);
   scanStartTime = ClockOnDate(now, InpStartHour, InpStartMinute);

   if(now < scanStartTime)
      return false;

   return LastFractalScanDay != scanDayStart;
}

void ClearFractalMarkers(const int ratesTotal)
{
   for(int i = 0; i < ratesTotal; i++)
   {
      UpperFractalBuffer[i] = EMPTY_VALUE;
      LowerFractalBuffer[i] = EMPTY_VALUE;
      BuyerSignalBuffer[i] = EMPTY_VALUE;
      SellerSignalBuffer[i] = EMPTY_VALUE;
      BuyerReversalBuffer[i] = EMPTY_VALUE;
      SellerReversalBuffer[i] = EMPTY_VALUE;
   }

   DeleteBreakerObjectsBySuffix("upper_fractal");
   DeleteBreakerObjectsBySuffix("lower_fractal");
   DeleteBreakerObjectsBySuffix("buyer_signal");
   DeleteBreakerObjectsBySuffix("seller_signal");
   DeleteBreakerObjectsBySuffix("buyer_reversal");
   DeleteBreakerObjectsBySuffix("seller_reversal");
   DeleteBreakerObjectsBySuffix("dragon_entry");
   DeleteBreakerObjectsBySuffix("dragon_stop");
}

datetime EndTimeForDay(const datetime dayStart)
{
   datetime endTime = ClockOnDate(dayStart, InpEndHour, InpEndMinute);
   const datetime startTime = ClockOnDate(dayStart, InpStartHour, InpStartMinute);

   if(endTime <= startTime)
      endTime += 86400;

   return endTime;
}

bool FindNearestFreshFractalForDay(
   const datetime dayStart,
   const bool upperFractal,
   const int ratesTotal,
   const bool series,
   const datetime &time[],
   const double &high[],
   const double &low[],
   const double &close[],
   datetime &fractalTime,
   double &fractalPrice
)
{
   const datetime startTime = ClockOnDate(dayStart, InpStartHour, InpStartMinute);
   datetime bestTime = 0;
   double bestPrice = 0.0;

   for(int i = 0; i < ratesTotal; i++)
   {
      const datetime barOpen = time[i];

      if(barOpen < dayStart || barOpen >= startTime)
         continue;

      if(upperFractal)
      {
         if(!IsUpperBillWilliamsFractal(i, ratesTotal, series, high))
            continue;

         if(HasCloseAbove(barOpen, dayStart, startTime, high[i], ratesTotal, time, close))
            continue;

         if(bestTime == 0 || barOpen > bestTime)
         {
            bestTime = barOpen;
            bestPrice = high[i];
         }
      }
      else
      {
         if(!IsLowerBillWilliamsFractal(i, ratesTotal, series, low))
            continue;

         if(HasCloseBelow(barOpen, dayStart, startTime, low[i], ratesTotal, time, close))
            continue;

         if(bestTime == 0 || barOpen > bestTime)
         {
            bestTime = barOpen;
            bestPrice = low[i];
         }
      }
   }

   if(bestTime == 0)
      return false;

   fractalTime = bestTime;
   fractalPrice = bestPrice;
   return true;
}

void DrawSignalMarker(
   const bool buyerSignal,
   const int index,
   const datetime markerTime,
   const double markerPrice
)
{
   if(!IsWithinWorkingTime(markerTime))
      return;

   if(buyerSignal)
   {
      if(InpDrawChartObjects)
         DrawMarkerObject("buyer_signal", markerTime, markerPrice, BREAKER_BUY_ARROW, InpBuyerSignalColor, InpSignalMarkerSize);
      else
         BuyerSignalBuffer[index] = markerPrice;

      return;
   }

   if(InpDrawChartObjects)
      DrawMarkerObject("seller_signal", markerTime, markerPrice, BREAKER_SELL_ARROW, InpSellerSignalColor, InpSignalMarkerSize);
   else
      SellerSignalBuffer[index] = markerPrice;
}

void DrawReversalMarker(
   const bool buyerSignal,
   const int index,
   const datetime markerTime,
   const double markerPrice
)
{
   if(!IsWithinWorkingTime(markerTime))
      return;

   if(buyerSignal)
   {
      if(InpDrawChartObjects)
         DrawMarkerObject("buyer_reversal", markerTime, markerPrice, BREAKER_BUY_ARROW, InpBuyerSignalColor, InpSignalMarkerSize);
      else
         BuyerReversalBuffer[index] = markerPrice;

      return;
   }

   if(InpDrawChartObjects)
      DrawMarkerObject("seller_reversal", markerTime, markerPrice, BREAKER_SELL_ARROW, InpSellerSignalColor, InpSignalMarkerSize);
   else
      SellerReversalBuffer[index] = markerPrice;
}

bool IsBullishCandle(const int index, const double &open[], const double &close[])
{
   return close[index] > open[index];
}

bool IsBearishCandle(const int index, const double &open[], const double &close[])
{
   return close[index] < open[index];
}

int PreviousClosedBarIndex(
   const datetime barTime,
   const int ratesTotal,
   const datetime &time[]
)
{
   int previousIndex = -1;
   datetime previousTime = 0;

   for(int i = 0; i < ratesTotal; i++)
   {
      if(time[i] >= barTime)
         continue;

      if(previousIndex < 0 || time[i] > previousTime)
      {
         previousIndex = i;
         previousTime = time[i];
      }
   }

   return previousIndex;
}

int NextClosedBarIndex(
   const datetime afterTime,
   const datetime beforeTime,
   const int ratesTotal,
   const datetime &time[]
)
{
   int nextIndex = -1;
   datetime nextTime = 0;

   for(int i = 0; i < ratesTotal; i++)
   {
      if(time[i] <= afterTime || time[i] >= beforeTime)
         continue;

      if(nextIndex < 0 || time[i] < nextTime)
      {
         nextIndex = i;
         nextTime = time[i];
      }
   }

   return nextIndex;
}

int LowestLowIndexBetween(
   const datetime fromTime,
   const datetime toTime,
   const int ratesTotal,
   const datetime &time[],
   const double &low[]
)
{
   int lowestIndex = -1;

   for(int i = 0; i < ratesTotal; i++)
   {
      if(time[i] < fromTime || time[i] > toTime)
         continue;

      if(lowestIndex < 0 || low[i] < low[lowestIndex])
         lowestIndex = i;
   }

   return lowestIndex;
}

int HighestHighIndexBetween(
   const datetime fromTime,
   const datetime toTime,
   const int ratesTotal,
   const datetime &time[],
   const double &high[]
)
{
   int highestIndex = -1;

   for(int i = 0; i < ratesTotal; i++)
   {
      if(time[i] < fromTime || time[i] > toTime)
         continue;

      if(highestIndex < 0 || high[i] > high[highestIndex])
         highestIndex = i;
   }

   return highestIndex;
}

void DrawDragonCircle(
   const string suffix,
   const datetime markerTime,
   const double markerPrice,
   const color markerColor
)
{
   DrawMarkerObject(suffix, markerTime, markerPrice, BREAKER_MARKER_ARROW, markerColor, InpDragonMarkerSize);
}

void DrawDragonEntryAndStop(
   const bool buyerDirection,
   const int entryIndex,
   const int dragonIndex,
   const int motherIndex,
   const int ratesTotal,
   const double markerOffset,
   const datetime &time[],
   const double &high[],
   const double &low[]
)
{
   if(entryIndex < 0 || dragonIndex < 0 || motherIndex < 0)
      return;

   if(buyerDirection)
   {
      DrawDragonCircle("dragon_entry", time[entryIndex], low[entryIndex] - markerOffset, InpEntryCircleColor);

      const int stopIndex = LowestLowIndexBetween(time[motherIndex], time[entryIndex], ratesTotal, time, low);
      if(stopIndex >= 0)
         DrawDragonCircle("dragon_stop", time[stopIndex], low[stopIndex] - markerOffset, InpStopCircleColor);

      return;
   }

   DrawDragonCircle("dragon_entry", time[entryIndex], high[entryIndex] + markerOffset, InpEntryCircleColor);

   const int stopIndex = HighestHighIndexBetween(time[motherIndex], time[entryIndex], ratesTotal, time, high);
   if(stopIndex >= 0)
      DrawDragonCircle("dragon_stop", time[stopIndex], high[stopIndex] + markerOffset, InpStopCircleColor);
}

bool TryDragonPhaseOne(
   const bool buyerDirection,
   const datetime segmentStart,
   const datetime segmentEnd,
   const int ratesTotal,
   const double markerOffset,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   int &dragonIndex,
   int &motherIndex,
   int &phaseTwoStartIndex
)
{
   dragonIndex = -1;
   motherIndex = -1;
   phaseTwoStartIndex = -1;

   datetime cursor = segmentStart;

   while(true)
   {
      const int currentIndex = NextClosedBarIndex(cursor, segmentEnd, ratesTotal, time);
      if(currentIndex < 0)
         return false;

      if((buyerDirection && IsBearishCandle(currentIndex, open, close))
         || (!buyerDirection && IsBullishCandle(currentIndex, open, close)))
      {
         motherIndex = currentIndex;
         dragonIndex = PreviousClosedBarIndex(time[motherIndex], ratesTotal, time);
         break;
      }

      cursor = time[currentIndex];
   }

   if(dragonIndex < 0)
      return false;

   cursor = time[motherIndex];

   while(true)
   {
      const int currentIndex = NextClosedBarIndex(cursor, segmentEnd, ratesTotal, time);
      if(currentIndex < 0)
         return false;

      if(buyerDirection)
      {
         if(IsBearishCandle(currentIndex, open, close) && close[currentIndex] < low[motherIndex])
         {
            phaseTwoStartIndex = currentIndex;
            return false;
         }

         if(close[currentIndex] > high[dragonIndex])
         {
            DrawDragonEntryAndStop(true, currentIndex, dragonIndex, motherIndex, ratesTotal, markerOffset, time, high, low);
            return true;
         }
      }
      else
      {
         if(IsBullishCandle(currentIndex, open, close) && close[currentIndex] > high[motherIndex])
         {
            phaseTwoStartIndex = currentIndex;
            return false;
         }

         if(close[currentIndex] < low[dragonIndex])
         {
            DrawDragonEntryAndStop(false, currentIndex, dragonIndex, motherIndex, ratesTotal, markerOffset, time, high, low);
            return true;
         }
      }

      cursor = time[currentIndex];
   }

   return false;
}

void RunDragonPhaseTwo(
   const bool buyerDirection,
   const int startIndex,
   const int dragonIndex,
   const datetime segmentEnd,
   const int ratesTotal,
   const double markerOffset,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[]
)
{
   if(startIndex < 0 || dragonIndex < 0)
      return;

   int masterIndex = -1;
   int confirmationCount = 0;
   datetime cursor = time[startIndex];
   bool includeStartIndex = true;

   while(true)
   {
      int currentIndex = -1;

      if(includeStartIndex)
      {
         currentIndex = startIndex;
         includeStartIndex = false;
      }
      else
      {
         currentIndex = NextClosedBarIndex(cursor, segmentEnd, ratesTotal, time);
      }

      if(currentIndex < 0)
         return;

      if(buyerDirection)
      {
         if(masterIndex < 0 || low[currentIndex] < low[masterIndex])
         {
            masterIndex = currentIndex;
            confirmationCount = 0;
         }

         if(masterIndex >= 0 && close[currentIndex] > high[dragonIndex])
         {
            DrawDragonCircle("dragon_entry", time[currentIndex], low[currentIndex] - markerOffset, InpEntryCircleColor);
            DrawDragonCircle("dragon_stop", time[masterIndex], low[masterIndex] - markerOffset, InpStopCircleColor);
            return;
         }

         if(masterIndex >= 0 && IsBullishCandle(currentIndex, open, close) && close[currentIndex] > high[masterIndex])
         {
            confirmationCount++;

            if(confirmationCount >= 2)
            {
               DrawDragonCircle("dragon_entry", time[currentIndex], low[currentIndex] - markerOffset, InpEntryCircleColor);
               DrawDragonCircle("dragon_stop", time[masterIndex], low[masterIndex] - markerOffset, InpStopCircleColor);
               return;
            }
         }
      }
      else
      {
         if(masterIndex < 0 || high[currentIndex] > high[masterIndex])
         {
            masterIndex = currentIndex;
            confirmationCount = 0;
         }

         if(masterIndex >= 0 && close[currentIndex] < low[dragonIndex])
         {
            DrawDragonCircle("dragon_entry", time[currentIndex], high[currentIndex] + markerOffset, InpEntryCircleColor);
            DrawDragonCircle("dragon_stop", time[masterIndex], high[masterIndex] + markerOffset, InpStopCircleColor);
            return;
         }

         if(masterIndex >= 0 && IsBearishCandle(currentIndex, open, close) && close[currentIndex] < low[masterIndex])
         {
            confirmationCount++;

            if(confirmationCount >= 2)
            {
               DrawDragonCircle("dragon_entry", time[currentIndex], high[currentIndex] + markerOffset, InpEntryCircleColor);
               DrawDragonCircle("dragon_stop", time[masterIndex], high[masterIndex] + markerOffset, InpStopCircleColor);
               return;
            }
         }
      }

      cursor = time[currentIndex];
   }
}

void ProcessDragonPhasesForSegment(
   const bool buyerDirection,
   const datetime segmentStart,
   const datetime segmentEnd,
   const int ratesTotal,
   const double markerOffset,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[]
)
{
   if(!InpShowDragonPhases)
      return;

   int dragonIndex = -1;
   int motherIndex = -1;
   int phaseTwoStartIndex = -1;

   if(TryDragonPhaseOne(buyerDirection, segmentStart, segmentEnd, ratesTotal, markerOffset, time, open, high, low, close, dragonIndex, motherIndex, phaseTwoStartIndex))
      return;

   RunDragonPhaseTwo(buyerDirection, phaseTwoStartIndex, dragonIndex, segmentEnd, ratesTotal, markerOffset, time, open, high, low, close);
}

bool FindStartCandleForDay(
   const datetime dayStart,
   const int ratesTotal,
   const bool series,
   const int periodSeconds,
   const datetime &time[],
   const double &high[],
   const double &low[],
   double &startHigh,
   double &startLow
)
{
   const datetime startTime = ClockOnDate(dayStart, InpStartHour, InpStartMinute);

   for(int i = 0; i < ratesTotal; i++)
   {
      const datetime barOpen = time[i];
      datetime nextBarOpen;

      if(series)
         nextBarOpen = (i == 0) ? barOpen + periodSeconds : time[i - 1];
      else
         nextBarOpen = (i == ratesTotal - 1) ? barOpen + periodSeconds : time[i + 1];

      if(TimeFallsInsideBar(startTime, barOpen, nextBarOpen))
      {
         startHigh = high[i];
         startLow = low[i];
         return true;
      }
   }

   return false;
}

int FindStartCandleIndexForDay(
   const datetime dayStart,
   const int ratesTotal,
   const bool series,
   const int periodSeconds,
   const datetime &time[]
)
{
   const datetime startTime = ClockOnDate(dayStart, InpStartHour, InpStartMinute);

   for(int i = 0; i < ratesTotal; i++)
   {
      const datetime barOpen = time[i];
      datetime nextBarOpen;

      if(series)
         nextBarOpen = (i == 0) ? barOpen + periodSeconds : time[i - 1];
      else
         nextBarOpen = (i == ratesTotal - 1) ? barOpen + periodSeconds : time[i + 1];

      if(TimeFallsInsideBar(startTime, barOpen, nextBarOpen))
         return i;
   }

   return -1;
}

bool DetermineInitialFreshFractalSignalForDay(
   const datetime dayStart,
   const int ratesTotal,
   const bool series,
   const datetime &time[],
   const double &high[],
   const double &low[],
   const double &close[],
   bool &buyerSignal,
   int &signalIndex,
   datetime &signalTime,
   double &upperPrice,
   double &lowerPrice,
   bool &hasUpper,
   bool &hasLower
)
{
   datetime upperTime = 0;
   datetime lowerTime = 0;
   upperPrice = 0.0;
   lowerPrice = 0.0;
   hasUpper = FindNearestFreshFractalForDay(dayStart, true, ratesTotal, series, time, high, low, close, upperTime, upperPrice);
   hasLower = FindNearestFreshFractalForDay(dayStart, false, ratesTotal, series, time, high, low, close, lowerTime, lowerPrice);

   const datetime startTime = ClockOnDate(dayStart, InpStartHour, InpStartMinute);
   const datetime endTime = EndTimeForDay(dayStart);
   signalTime = 0;
   signalIndex = -1;
   buyerSignal = false;

   if(!hasUpper || !hasLower)
   {
      const int startIndex = FindStartCandleIndexForDay(dayStart, ratesTotal, series, SafePeriodSeconds(), time);
      if(startIndex < 0)
         return false;

      signalIndex = startIndex;
      signalTime = time[startIndex];
      if(signalTime < startTime || signalTime >= endTime)
         return false;

      buyerSignal = !hasUpper;
      return true;
   }

   for(int i = 0; i < ratesTotal; i++)
   {
      const datetime barOpen = time[i];

      if(barOpen < startTime || barOpen >= endTime)
         continue;

      if(hasUpper && close[i] > upperPrice)
      {
         if(signalTime == 0 || barOpen < signalTime)
         {
            signalTime = barOpen;
            signalIndex = i;
            buyerSignal = true;
         }
      }

      if(hasLower && close[i] < lowerPrice)
      {
         if(signalTime == 0 || barOpen < signalTime)
         {
            signalTime = barOpen;
            signalIndex = i;
            buyerSignal = false;
         }
      }
   }

   return signalIndex >= 0;
}

bool ScanFreshFractalReversalForDay(
   const datetime dayStart,
   const int ratesTotal,
   const bool series,
   const int periodSeconds,
   const double signalOffset,
   const datetime &time[],
   const double &high[],
   const double &low[],
   const double &close[],
   const bool initialBuyer,
   const datetime initialSignalTime,
   const double upperPrice,
   const double lowerPrice,
   const bool hasUpper,
   const bool hasLower,
   bool &reversalBuyer,
   datetime &reversalTimeResult
)
{
   reversalBuyer = false;
   reversalTimeResult = 0;

   if(!InpShowFreshFractalReversals)
      return false;

   double startHigh = 0.0;
   double startLow = 0.0;

   if(!FindStartCandleForDay(dayStart, ratesTotal, series, periodSeconds, time, high, low, startHigh, startLow))
      return false;

   const datetime endTime = EndTimeForDay(dayStart);
   datetime setupTime = 0;

   for(int i = 0; i < ratesTotal; i++)
   {
      const datetime barOpen = time[i];

      if(barOpen <= initialSignalTime || barOpen >= endTime)
         continue;

      if(!initialBuyer && close[i] > startHigh)
      {
         if(setupTime == 0 || barOpen < setupTime)
            setupTime = barOpen;
      }

      if(initialBuyer && close[i] < startLow)
      {
         if(setupTime == 0 || barOpen < setupTime)
            setupTime = barOpen;
      }
   }

   if(setupTime == 0)
      return false;

   datetime reversalTime = 0;
   int reversalIndex = -1;

   for(int i = 0; i < ratesTotal; i++)
   {
      const datetime barOpen = time[i];

      if(barOpen <= setupTime || barOpen >= endTime)
         continue;

      if(!initialBuyer && hasUpper && close[i] > upperPrice)
      {
         if(reversalTime == 0 || barOpen < reversalTime)
         {
            reversalTime = barOpen;
            reversalIndex = i;
         }
      }

      if(initialBuyer && hasLower && close[i] < lowerPrice)
      {
         if(reversalTime == 0 || barOpen < reversalTime)
         {
            reversalTime = barOpen;
            reversalIndex = i;
         }
      }
   }

   if(reversalIndex < 0)
      return false;

   if(!initialBuyer)
   {
      DrawReversalMarker(true, reversalIndex, reversalTime, low[reversalIndex] - signalOffset);
      reversalBuyer = true;
   }
   else
   {
      DrawReversalMarker(false, reversalIndex, reversalTime, high[reversalIndex] + signalOffset);
      reversalBuyer = false;
   }

   reversalTimeResult = reversalTime;
   return true;
}

void ScanFreshFractalSignalForDay(
   const datetime dayStart,
   const int ratesTotal,
   const bool series,
   const int periodSeconds,
   const double signalOffset,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[]
)
{
   if(!InpShowFreshFractalSignals)
      return;

   bool buyerSignal = false;
   int signalIndex = -1;
   datetime signalTime = 0;
   double upperPrice = 0.0;
   double lowerPrice = 0.0;
   bool hasUpper = false;
   bool hasLower = false;

   if(!DetermineInitialFreshFractalSignalForDay(dayStart, ratesTotal, series, time, high, low, close, buyerSignal, signalIndex, signalTime, upperPrice, lowerPrice, hasUpper, hasLower))
      return;

   if(buyerSignal)
      DrawSignalMarker(true, signalIndex, signalTime, low[signalIndex] - signalOffset);
   else
      DrawSignalMarker(false, signalIndex, signalTime, high[signalIndex] + signalOffset);

   bool reversalBuyer = false;
   datetime reversalTime = 0;
   const bool hasReversal = ScanFreshFractalReversalForDay(dayStart, ratesTotal, series, periodSeconds, signalOffset, time, high, low, close, buyerSignal, signalTime, upperPrice, lowerPrice, hasUpper, hasLower, reversalBuyer, reversalTime);
   const datetime endTime = EndTimeForDay(dayStart);
   const double dragonOffset = MathMax(InpDragonMarkerOffsetPoints, 0) * _Point;

   if(hasReversal)
   {
      ProcessDragonPhasesForSegment(buyerSignal, signalTime, reversalTime, ratesTotal, dragonOffset, time, open, high, low, close);
      ProcessDragonPhasesForSegment(reversalBuyer, reversalTime, endTime, ratesTotal, dragonOffset, time, open, high, low, close);
      return;
   }

   ProcessDragonPhasesForSegment(buyerSignal, signalTime, endTime, ratesTotal, dragonOffset, time, open, high, low, close);
}

void ScanUnbrokenFractalsRange(
   const datetime latestScanDayStart,
   const int ratesTotal,
   const bool series,
   const double fractalOffset,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[]
)
{
   ClearFractalMarkers(ratesTotal);

   if(!InpShowUnbrokenFractals)
      return;

   const int lookbackDays = MathMax(InpFractalLookbackDays, 1);
   const datetime oldestScanDayStart = latestScanDayStart - (lookbackDays - 1) * 86400;

   for(int i = 0; i < ratesTotal; i++)
   {
      const datetime barOpen = time[i];
      const datetime barDayStart = DayStart(barOpen);
      const datetime barStartTime = ClockOnDate(barOpen, InpStartHour, InpStartMinute);

      if(barDayStart < oldestScanDayStart || barDayStart > latestScanDayStart)
         continue;

      if(barOpen < barDayStart || barOpen >= barStartTime)
         continue;

      if(IsUpperBillWilliamsFractal(i, ratesTotal, series, high)
         && !HasCloseAbove(barOpen, barDayStart, barStartTime, high[i], ratesTotal, time, close))
      {
         const double markerPrice = high[i] + fractalOffset;

         if(InpDrawChartObjects)
            DrawMarkerObject("upper_fractal", barOpen, markerPrice, BREAKER_UP_TRIANGLE, InpFractalMarkerColor, InpFractalMarkerSize);
         else
            UpperFractalBuffer[i] = markerPrice;
      }

      if(IsLowerBillWilliamsFractal(i, ratesTotal, series, low)
         && !HasCloseBelow(barOpen, barDayStart, barStartTime, low[i], ratesTotal, time, close))
      {
         const double markerPrice = low[i] - fractalOffset;

         if(InpDrawChartObjects)
            DrawMarkerObject("lower_fractal", barOpen, markerPrice, BREAKER_DOWN_TRIANGLE, InpFractalMarkerColor, InpFractalMarkerSize);
         else
            LowerFractalBuffer[i] = markerPrice;
      }
   }

   const int periodSeconds = SafePeriodSeconds();
   for(int day = 0; day < lookbackDays; day++)
      ScanFreshFractalSignalForDay(latestScanDayStart - day * 86400, ratesTotal, series, periodSeconds, MathMax(InpSignalMarkerOffsetPoints, 0) * _Point, time, open, high, low, close);
}

void BuildTimeMarkers(
   const int ratesTotal,
   const bool series,
   const int periodSeconds,
   const double markerOffset,
   const datetime &time[],
   const double &low[]
)
{
   DeleteBreakerObjectsBySuffix("start");
   DeleteBreakerObjectsBySuffix("end");

   for(int i = 0; i < ratesTotal; i++)
   {
      StartMarkerBuffer[i] = EMPTY_VALUE;
      EndMarkerBuffer[i] = EMPTY_VALUE;

      if(!InpShowTimeMarkers)
         continue;

      const datetime barOpen = time[i];
      datetime nextBarOpen;

      if(series)
         nextBarOpen = (i == 0) ? barOpen + periodSeconds : time[i - 1];
      else
         nextBarOpen = (i == ratesTotal - 1) ? barOpen + periodSeconds : time[i + 1];

      const datetime startTime = ClockOnDate(barOpen, InpStartHour, InpStartMinute);
      const datetime endTime = ClockOnDate(barOpen, InpEndHour, InpEndMinute);
      const double markerPrice = low[i] - markerOffset;

      if(TimeFallsInsideBar(startTime, barOpen, nextBarOpen))
      {
         if(InpDrawChartObjects)
            DrawMarkerObject("start", barOpen, markerPrice, BREAKER_MARKER_ARROW, InpStartMarkerColor, InpMarkerSize);
         else
            StartMarkerBuffer[i] = markerPrice;
      }

      if(TimeFallsInsideBar(endTime, barOpen, nextBarOpen))
      {
         if(InpDrawChartObjects)
            DrawMarkerObject("end", barOpen, markerPrice, BREAKER_MARKER_ARROW, InpEndMarkerColor, InpMarkerSize);
         else
            EndMarkerBuffer[i] = markerPrice;
      }
   }
}

void RunInitialFractalPreview(
   const datetime now,
   const int ratesTotal,
   const bool series,
   const double fractalOffset,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[]
)
{
   const datetime scanDayStart = DayStart(now);
   datetime scanStartTime = ClockOnDate(now, InpStartHour, InpStartMinute);

   ScanUnbrokenFractalsRange(scanDayStart, ratesTotal, series, fractalOffset, time, open, high, low, close);

   if(now >= scanStartTime)
      LastFractalScanDay = scanDayStart;

   FractalBuffersInitialized = true;
}

string TimeSourceLabel()
{
   if(InpTimeSource == BREAKER_TIME_CHART)
      return "Chart candles";

   if(InpTimeSource == BREAKER_TIME_LOCAL)
      return "Local";

   return "Server";
}

void UpdateBreakerStatus(const datetime now, const bool isActive)
{
   if(!InpShowStatusOnChart)
      return;

   MqlDateTime parts;
   TimeToStruct(now, parts);

   Comment(StringFormat(
      "breaker %s\nStart time: %s\nEnd time: %s\nFractal lookback: %d days\nTime source: %s\nLast candle-close update: %02d:%02d\nStatus: %s\nFractal scan: %s",
      BREAKER_VERSION,
      FormatClock(InpStartHour, InpStartMinute),
      FormatClock(InpEndHour, InpEndMinute),
      MathMax(InpFractalLookbackDays, 1),
      TimeSourceLabel(),
      parts.hour,
      parts.min,
      isActive ? "ACTIVE" : "WAITING",
      LastFractalScanDay == DayStart(now) ? "DONE" : "WAITING"
   ));
}

int OnInit()
{
   DeleteBreakerObjects();
   IndicatorSetString(INDICATOR_SHORTNAME, BREAKER_VERSION);
   SetIndexBuffer(0, StartMarkerBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, EndMarkerBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, UpperFractalBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, LowerFractalBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, BuyerSignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, SellerSignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, BuyerReversalBuffer, INDICATOR_DATA);
   SetIndexBuffer(7, SellerReversalBuffer, INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_ARROW, BREAKER_MARKER_ARROW);
   PlotIndexSetInteger(1, PLOT_ARROW, BREAKER_MARKER_ARROW);
   PlotIndexSetInteger(2, PLOT_ARROW, BREAKER_UP_TRIANGLE);
   PlotIndexSetInteger(3, PLOT_ARROW, BREAKER_DOWN_TRIANGLE);
   PlotIndexSetInteger(4, PLOT_ARROW, BREAKER_BUY_ARROW);
   PlotIndexSetInteger(5, PLOT_ARROW, BREAKER_SELL_ARROW);
   PlotIndexSetInteger(6, PLOT_ARROW, BREAKER_BUY_ARROW);
   PlotIndexSetInteger(7, PLOT_ARROW, BREAKER_SELL_ARROW);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpStartMarkerColor);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpEndMarkerColor);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpFractalMarkerColor);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpFractalMarkerColor);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpBuyerSignalColor);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpSellerSignalColor);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, InpBuyerSignalColor);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, InpSellerSignalColor);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpMarkerSize);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpMarkerSize);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpFractalMarkerSize);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpFractalMarkerSize);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, InpSignalMarkerSize);
   PlotIndexSetInteger(5, PLOT_LINE_WIDTH, InpSignalMarkerSize);
   PlotIndexSetInteger(6, PLOT_LINE_WIDTH, InpSignalMarkerSize);
   PlotIndexSetInteger(7, PLOT_LINE_WIDTH, InpSignalMarkerSize);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(!InputsAreValid())
   {
      PrintFormat(
         "breaker %s: invalid inputs. Start=%s End=%s LookbackDays=%d",
         BREAKER_VERSION,
         FormatClock(InpStartHour, InpStartMinute),
         FormatClock(InpEndHour, InpEndMinute),
         InpFractalLookbackDays
      );
      return INIT_PARAMETERS_INCORRECT;
   }

   const datetime now = BreakerNow();
   UpdateBreakerStatus(now, IsWithinWorkingTime(now));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(InpShowStatusOnChart)
      Comment("");

   DeleteBreakerObjects();
}

int OnCalculate(
   const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[]
)
{
   ArraySetAsSeries(StartMarkerBuffer, ArrayGetAsSeries(time));
   ArraySetAsSeries(EndMarkerBuffer, ArrayGetAsSeries(time));
   ArraySetAsSeries(UpperFractalBuffer, ArrayGetAsSeries(time));
   ArraySetAsSeries(LowerFractalBuffer, ArrayGetAsSeries(time));
   ArraySetAsSeries(BuyerSignalBuffer, ArrayGetAsSeries(time));
   ArraySetAsSeries(SellerSignalBuffer, ArrayGetAsSeries(time));
   ArraySetAsSeries(BuyerReversalBuffer, ArrayGetAsSeries(time));
   ArraySetAsSeries(SellerReversalBuffer, ArrayGetAsSeries(time));

   const bool series = ArrayGetAsSeries(time);
   const datetime currentBarOpen = CurrentBarOpen(rates_total, series, time);

   if(!ShouldProcessClosedCandle(currentBarOpen, prev_calculated))
      return rates_total;

   LastProcessedBarOpen = currentBarOpen;

   const datetime updateTime = currentBarOpen;
   const bool canWork = IsWithinWorkingTime(updateTime);
   const int periodSeconds = SafePeriodSeconds();
   const double markerOffset = MathMax(InpMarkerOffsetPoints, 0) * _Point;
   const double fractalOffset = MathMax(InpFractalMarkerOffsetPoints, 0) * _Point;

   if(!TimeMarkersInitialized || prev_calculated == 0)
   {
      BuildTimeMarkers(rates_total, series, periodSeconds, markerOffset, time, low);
      TimeMarkersInitialized = true;
   }

   if(!FractalBuffersInitialized)
   {
      RunInitialFractalPreview(updateTime, rates_total, series, fractalOffset, time, open, high, low, close);
   }

   datetime scanDayStart = 0;
   datetime scanStartTime = 0;
   const bool scanDue = FractalScanIsDue(updateTime, scanDayStart, scanStartTime);

   if(scanDue)
   {
      ScanUnbrokenFractalsRange(scanDayStart, rates_total, series, fractalOffset, time, open, high, low, close);
      LastFractalScanDay = scanDayStart;
   }
   else if(updateTime >= ClockOnDate(updateTime, InpStartHour, InpStartMinute)
      && updateTime <= EndTimeForDay(DayStart(updateTime)))
   {
      ScanFreshFractalSignalForDay(DayStart(updateTime), rates_total, series, periodSeconds, MathMax(InpSignalMarkerOffsetPoints, 0) * _Point, time, open, high, low, close);
   }

   UpdateBreakerStatus(updateTime, canWork);

   ChartRedraw(0);

   if(!canWork)
      return rates_total;

   // Future breaker logic will run only inside the configured time window.
   return rates_total;
}
