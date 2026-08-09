//+------------------------------------------------------------------+
//|                                               LamborghiniEA.mq5   |
//| Prototype EA for XAUUSD M2/M5 execution with M15 context.         |
//| This is not financial advice. Backtest and demo-test first.       |
//+------------------------------------------------------------------+
#property copyright "Lamborghini EA"
#property link      "https://github.com/ngannguyen19390506-droid/lamborgini"
#property version   "1.03"
#property strict

#include <Trade/Trade.mqh>

enum Direction
{
   DIR_NONE = 0,
   DIR_BUY  = 1,
   DIR_SELL = -1
};

enum MarketRegime
{
   REGIME_UNKNOWN = 0,
   REGIME_STRONG_UPTREND,
   REGIME_UPTREND,
   REGIME_STRONG_DOWNTREND,
   REGIME_DOWNTREND,
   REGIME_RANGE,
   REGIME_COMPRESSION,
   REGIME_BREAKOUT,
   REGIME_HIGH_VOLATILITY,
   REGIME_CHAOTIC
};

enum TradingState
{
   STATE_RUNNING = 0,
   STATE_NO_NEW_ENTRY,
   STATE_RECOVERY_ONLY,
   STATE_CLOSE_ONLY,
   STATE_PAUSED,
   STATE_EMERGENCY
};

enum LotMode
{
   LOT_FIXED = 0,
   LOT_RISK_PERCENT,
   LOT_SMART
};

enum EntryExecution
{
   EXEC_MARKET = 0,
   EXEC_LIMIT,
   EXEC_STOP
};

struct RegimeInfo
{
   MarketRegime regime;
   double emaFast;
   double emaSlow;
   double emaGapAtr;
   double emaSlopeAtr;
   double atr;
   double atrRatio;
   double adx;
   double bbWidthAtr;
   string label;
};

struct BasketInfo
{
   int count;
   double lots;
   double avgPrice;
   double floating;
   double weightedPrice;
   double lastEntryPrice;
   datetime lastEntryTime;
};

struct SignalFeatures
{
   bool sweep;
   bool reclaim;
   bool choch;
   bool engulfing;
   bool pinbar;
   bool rejection;
   int score;
   string tags;
};

struct TradeSignal
{
   bool valid;
   Direction direction;
   string strategy;
   int score;
   double idealEntry;
   double orderPrice;
   double sl;
   double tp;
   double invalidation;
   double rr;
   EntryExecution execution;
   int contextScore;
   int structureScore;
   int setupScore;
   int locationScore;
   int paScore;
   int momentumScore;
   int volatilityScore;
   int spreadScore;
   int sessionScore;
   string reason;
};

input group "Core"
input string          InpTradeSymbol              = "";
input ulong           InpMagicNumber              = 19390506;
input ENUM_TIMEFRAMES InpContextTf                = PERIOD_M15;
input ENUM_TIMEFRAMES InpSetupTf                  = PERIOD_M5;
input ENUM_TIMEFRAMES InpTriggerTf                = PERIOD_M2;
input TradingState    InpManualState              = STATE_RUNNING;
input bool            InpAllowHedgedBaskets       = true;
input bool            InpOneEntryPerM2Bar         = true;

input group "Signal Scoring"
input int             InpMinEntryScore            = 75;
input bool            InpUseAdaptiveEntryThreshold= true;
input int             InpMinAdaptiveEntryScore    = 70;
input int             InpAlignedContextDiscount   = 3;
input int             InpRangeSweepDiscount       = 2;
input int             InpWeakContextPenalty       = 6;
input int             InpHighVolatilityPenalty    = 3;
input int             InpMinRecoveryScore         = 83;
input int             InpRecoveryScoreStep        = 5;
input int             InpMinPyramidScore          = 80;
input int             InpCounterTrendScoreBump    = 8;
input bool            InpAllowCounterTrendReversal= true;
input int             InpMinPullbackPaScore       = 3;
input int             InpMinFvgPaScore            = 3;
input int             InpMinBreakoutPaScore       = 3;
input int             InpMinSweepPaScore          = 8;
input int             InpMinLocationScore         = 7;
input bool            InpRequirePendingForWeakPA  = true;

input group "Indicators"
input int             InpEmaFast                  = 21;
input int             InpEmaSlow                  = 55;
input int             InpAtrPeriod                = 14;
input int             InpAdxPeriod                = 14;
input int             InpRsiPeriod                = 14;
input int             InpBandsPeriod              = 20;
input double          InpBandsDeviation           = 2.0;

input group "Regime"
input double          InpStrongTrendAdx           = 27.0;
input double          InpTrendAdx                 = 18.0;
input double          InpRangeAdx                 = 17.0;
input double          InpCompressionBbAtr         = 2.10;
input double          InpCompressionAtrRatio      = 0.80;
input double          InpHighVolAtrRatio          = 1.80;
input double          InpChaoticAtrRatio          = 2.40;
input double          InpMaxEmaAtrDistance        = 1.45;

input group "Strategy Lookbacks"
input int             InpStructureLookback        = 8;
input int             InpSweepLookback            = 10;
input int             InpChochLookback            = 5;
input int             InpFvgLookback              = 30;
input int             InpBreakoutLookback         = 28;
input int             InpTargetLookback           = 42;
input double          InpZoneAtrBuffer            = 0.25;

input group "Entry And Exit"
input double          InpAtrSlBuffer              = 0.35;
input double          InpMinExpectedRR            = 1.45;
input double          InpDefaultRR                = 2.00;
input bool            InpUseRoomToTargetFilter    = true;
input bool            InpSkipIfRoomTooSmall       = false;
input double          InpMaxEntryAtrDeviation     = 0.35;
input int             InpMaxSlippagePoints        = 40;
input bool            InpUsePendingOrders         = true;
input int             InpMaxPendingOrders         = 2;
input int             InpPendingExpiryBars        = 3;
input double          InpMinPendingDistancePoints = 30.0;
input double          InpLimitEntryAtrOffset      = 0.10;
input double          InpStopEntryAtrOffset       = 0.12;
input double          InpMaxPendingAtrDistance    = 2.50;
input bool            InpCancelInvalidPending     = true;

input group "Lot Management"
input LotMode         InpLotMode                   = LOT_SMART;
input double          InpFixedLot                  = 0.02;
input double          InpRiskPerTradePct           = 0.35;
input double          InpMinLot                    = 0.01;
input double          InpMaxInitialLot             = 0.10;
input double          InpMaxReentryLot             = 0.10;
input double          InpPyramidLotFactor          = 0.70;
input double          InpRecoveryLotAddPct         = 0.00;
input bool            InpAllowMinLotWhenRiskSmall  = false;

input group "Risk Supervisor"
input double          InpRecoveryOnlyDdPct         = 10.0;
input double          InpMaxDrawdownPct            = 15.0;
input double          InpEmergencyDrawdownPct      = 25.0;
input bool            InpEmergencyCloseAll         = false;
input double          InpMaxFloatingLossMoney      = 0.0;
input double          InpMaxBasketLossMoney        = 0.0;
input double          InpMaxBasketRiskPct          = 1.50;
input double          InpMaxBasketLot              = 0.25;
input double          InpMaxTotalLot               = 0.40;
input int             InpMaxPositionsPerBasket     = 3;
input int             InpMaxTradesPerHour          = 6;
input int             InpMaxConsecutiveLosses      = 5;
input double          InpMaxMarginUsagePct         = 45.0;
input int             InpMaxSpreadPoints           = 120;
input bool            InpUseAdaptiveSpreadLimit    = true;
input double          InpSpreadLimitMultiplier     = 1.35;
input int             InpAdaptiveSpreadCapPoints   = 360;
input double          InpMinReentrySpacingAtr      = 0.70;

input group "Basket Management"
input bool            InpUseBasketTrailing         = true;
input double          InpBasketTrailStartMoney     = 5.0;
input double          InpBasketTrailLockMoney      = 3.0;
input double          InpBasketTrailGivebackMoney  = 2.0;
input bool            InpCloseInvalidatedBasket    = false;
input bool            InpUseCrossBasketNetExit     = true;
input double          InpCrossBasketNetTargetMoney = 8.0;
input double          InpCrossBasketOffsetRatio    = 1.20;

input group "Session"
input bool            InpUseSessionScore           = true;
input bool            InpHardSessionFilter         = false;
input bool            InpTradeAsian                = false;
input bool            InpTradeLondon               = true;
input bool            InpTradeNewYork              = true;
input int             InpCustomSessionStartGmt     = -1;
input int             InpCustomSessionEndGmt       = -1;

input group "Journal"
input bool            InpWriteJournal              = true;
input string          InpJournalFileName           = "LamborghiniEA_journal.csv";
input bool            InpTrackMaeMfe               = true;
input bool            InpWriteCandidateEvents      = true;
input bool            InpWriteDailyAnalysis        = true;
input string          InpDailyEventFileName        = "LamborghiniEA_daily_events.csv";
input string          InpDailySummaryFileName      = "LamborghiniEA_daily_summary.csv";

CTrade Trade;

string TradeSymbol = "";

int hEmaFastContext = INVALID_HANDLE;
int hEmaSlowContext = INVALID_HANDLE;
int hEmaFastSetup   = INVALID_HANDLE;
int hEmaSlowSetup   = INVALID_HANDLE;
int hEmaFastTrigger = INVALID_HANDLE;
int hAtrContext     = INVALID_HANDLE;
int hAtrSetup       = INVALID_HANDLE;
int hAtrTrigger     = INVALID_HANDLE;
int hAdxContext     = INVALID_HANDLE;
int hAdxSetup       = INVALID_HANDLE;
int hRsiTrigger     = INVALID_HANDLE;
int hBandsContext   = INVALID_HANDLE;
int hBandsSetup     = INVALID_HANDLE;

datetime g_lastSignalBar = 0;
datetime g_lastBuyEntryBar = 0;
datetime g_lastSellEntryBar = 0;
double g_peakEquity = 0.0;
string g_activeAnalysisDate = "";

string ResolveTradeSymbol()
{
   if(InpTradeSymbol == "")
   {
      if(SymbolSelect(_Symbol, true))
         return _Symbol;
      return "";
   }

   if(SymbolSelect(InpTradeSymbol, true))
      return InpTradeSymbol;

   if(_Symbol != "" && StringFind(_Symbol, InpTradeSymbol) == 0 &&
      SymbolSelect(_Symbol, true))
   {
      Print("Input symbol ", InpTradeSymbol, " not found. Using tester/chart symbol ",
            _Symbol, " instead.");
      return _Symbol;
   }

   return "";
}

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   TradeSymbol = ResolveTradeSymbol();
   if(TradeSymbol == "")
   {
      Print("Cannot select trade symbol. Input=", InpTradeSymbol,
            ", tester/chart symbol=", _Symbol);
      return INIT_FAILED;
   }

   hEmaFastContext = iMA(TradeSymbol, InpContextTf, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hEmaSlowContext = iMA(TradeSymbol, InpContextTf, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hEmaFastSetup   = iMA(TradeSymbol, InpSetupTf,   InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hEmaSlowSetup   = iMA(TradeSymbol, InpSetupTf,   InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hEmaFastTrigger = iMA(TradeSymbol, InpTriggerTf, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hAtrContext     = iATR(TradeSymbol, InpContextTf, InpAtrPeriod);
   hAtrSetup       = iATR(TradeSymbol, InpSetupTf,   InpAtrPeriod);
   hAtrTrigger     = iATR(TradeSymbol, InpTriggerTf, InpAtrPeriod);
   hAdxContext     = iADX(TradeSymbol, InpContextTf, InpAdxPeriod);
   hAdxSetup       = iADX(TradeSymbol, InpSetupTf,   InpAdxPeriod);
   hRsiTrigger     = iRSI(TradeSymbol, InpTriggerTf, InpRsiPeriod, PRICE_CLOSE);
   hBandsContext   = iBands(TradeSymbol, InpContextTf, InpBandsPeriod, 0, InpBandsDeviation, PRICE_CLOSE);
   hBandsSetup     = iBands(TradeSymbol, InpSetupTf,   InpBandsPeriod, 0, InpBandsDeviation, PRICE_CLOSE);

   if(!IndicatorsReady())
      return INIT_FAILED;

   Trade.SetExpertMagicNumber(InpMagicNumber);
   Trade.SetDeviationInPoints(InpMaxSlippagePoints);
   Trade.SetTypeFillingBySymbol(TradeSymbol);

   string peakKey = GvKey("PeakEquity");
   if(GlobalVariableCheck(peakKey))
      g_peakEquity = GlobalVariableGet(peakKey);
   else
   {
      g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      GlobalVariableSet(peakKey, g_peakEquity);
   }

   InitJournal();
   InitDailyAnalytics();

   Print("LamborghiniEA initialized on ", TradeSymbol,
         ". Attach to the traded symbol chart for live ticks.");
   Print("Spread guard base=", InpMaxSpreadPoints,
         ", adaptive=", (InpUseAdaptiveSpreadLimit ? "true" : "false"),
         ", effective_now=", EffectiveMaxSpreadPoints());
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   FlushDailySummary(g_activeAnalysisDate, "deinit");

   ReleaseHandle(hEmaFastContext);
   ReleaseHandle(hEmaSlowContext);
   ReleaseHandle(hEmaFastSetup);
   ReleaseHandle(hEmaSlowSetup);
   ReleaseHandle(hEmaFastTrigger);
   ReleaseHandle(hAtrContext);
   ReleaseHandle(hAtrSetup);
   ReleaseHandle(hAtrTrigger);
   ReleaseHandle(hAdxContext);
   ReleaseHandle(hAdxSetup);
   ReleaseHandle(hRsiTrigger);
   ReleaseHandle(hBandsContext);
   ReleaseHandle(hBandsSetup);
}

//+------------------------------------------------------------------+
//| Expert tick                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!MarketDataReady())
      return;

   UpdatePeakEquity();
   UpdatePositionExcursions();

   BasketInfo buyBasket;
   BasketInfo sellBasket;
   BuildBasket(DIR_BUY, buyBasket);
   BuildBasket(DIR_SELL, sellBasket);

   RegimeInfo regime = DetectRegime();
   ManageBaskets(regime, buyBasket, sellBasket);
   ManagePendingOrders(regime);

   TradingState state = EffectiveTradingState(buyBasket, sellBasket);
   if(state == STATE_EMERGENCY && InpEmergencyCloseAll)
   {
      CloseAllOwnedPositions("EMERGENCY_DD");
      return;
   }

   datetime currentM2Bar = iTime(TradeSymbol, InpTriggerTf, 0);
   if(currentM2Bar == 0)
      return;

   if(InpOneEntryPerM2Bar && currentM2Bar == g_lastSignalBar)
      return;

   g_lastSignalBar = currentM2Bar;

   TradeSignal best = FindBestSignal(regime);
   if(!best.valid)
      return;

   if(InpWriteCandidateEvents)
   {
      WriteJournal("CANDIDATE", DirectionName(best.direction), best.strategy,
                   regime.label, best.score, best.idealEntry, best.sl, best.tp,
                   0.0, best.rr, SpreadPoints(), 0.0, best.reason,
                   ExecutionName(best.execution), best.orderPrice);
   }

   TryOpenSignal(best, state);
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
      return;

   if(!HistoryDealSelect(trans.deal))
      return;

   string symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
   long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(symbol != TradeSymbol || magic != (long)InpMagicNumber)
      return;

   long entryType = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   ulong positionId = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   if(entryType == DEAL_ENTRY_IN)
   {
      SeedPositionExcursion(positionId);
      StorePositionStrategyCode(positionId, DealStrategyCode(trans.deal));
      return;
   }

   if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_INOUT)
      return;

   double maeMoney = 0.0;
   double mfeMoney = 0.0;
   ReadPositionExcursions(positionId, maeMoney, mfeMoney);

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   long dealType = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   string side = (dealType == DEAL_TYPE_SELL ? "BUY" : "SELL");
   string strategyCode = PositionStrategyCode(positionId);
   WriteJournal("EXIT", side, strategyCode, "", 0, 0.0, 0.0, 0.0, 0.0,
                0.0, 0.0, profit, "deal_close", "", 0.0, maeMoney, mfeMoney);

   if(!PositionIdStillOpen(positionId))
      DeletePositionExcursions(positionId);
}

//+------------------------------------------------------------------+
//| Signal selection                                                  |
//+------------------------------------------------------------------+
TradeSignal FindBestSignal(const RegimeInfo &regime)
{
   TradeSignal best = EmptySignal();
   KeepBest(best, DetectTrendPullback(DIR_BUY, regime));
   KeepBest(best, DetectTrendPullback(DIR_SELL, regime));
   KeepBest(best, DetectLiquiditySweep(DIR_BUY, regime));
   KeepBest(best, DetectLiquiditySweep(DIR_SELL, regime));
   KeepBest(best, DetectFvgRetracement(DIR_BUY, regime));
   KeepBest(best, DetectFvgRetracement(DIR_SELL, regime));
   KeepBest(best, DetectBreakoutRetest(DIR_BUY, regime));
   KeepBest(best, DetectBreakoutRetest(DIR_SELL, regime));
   return best;
}

void KeepBest(TradeSignal &best, const TradeSignal &candidate)
{
   if(!candidate.valid)
      return;
   if(!best.valid || candidate.score > best.score)
      best = candidate;
}

TradeSignal DetectTrendPullback(const Direction dir, const RegimeInfo &regime)
{
   TradeSignal s = EmptySignal();
   s.direction = dir;
   s.strategy = "TrendPullback";

   if(IsStrongOpposite(dir, regime.regime))
      return s;

   double emaFast = BufferValue(hEmaFastSetup, 0, 1);
   double emaSlow = BufferValue(hEmaSlowSetup, 0, 1);
   double atr = BufferValue(hAtrSetup, 0, 1);
   if(atr <= 0.0)
      return s;

   double close1 = iClose(TradeSymbol, InpSetupTf, 1);
   double high1 = iHigh(TradeSymbol, InpSetupTf, 1);
   double low1 = iLow(TradeSymbol, InpSetupTf, 1);

   bool trendOk = (dir == DIR_BUY ? emaFast >= emaSlow : emaFast <= emaSlow);
   if(!trendOk && regime.regime != REGIME_RANGE)
      return s;

   bool touchedZone = false;
   if(dir == DIR_BUY)
      touchedZone = (low1 <= emaFast + atr * InpZoneAtrBuffer && close1 >= emaSlow);
   else
      touchedZone = (high1 >= emaFast - atr * InpZoneAtrBuffer && close1 <= emaSlow);

   double price = CurrentEntryPrice(dir);
   double distanceAtr = MathAbs(price - emaFast) / atr;
   if(!touchedZone || distanceAtr > InpMaxEmaAtrDistance)
      return s;

   SignalFeatures pa = AnalyzeTriggerPriceAction(dir);
   if(pa.score < InpMinPullbackPaScore)
      return s;

   int setupScore = 11;
   double fvgLow = 0.0;
   double fvgHigh = 0.0;
   int locationScore = 7 + (NearSupportResistance(dir, InpSetupTf) ? 4 : 0)
                         + (FindActiveFvg(dir, fvgLow, fvgHigh) ? 4 : 0);
   locationScore = ClampInt(locationScore, 0, 15);

   ApplyScore(s, dir, regime, setupScore, locationScore, pa, "TrendPullback");

   double desiredEntry = CurrentEntryPrice(dir);
   EntryExecution execution = EXEC_MARKET;
   double limitEntry = PullbackLimitPrice(dir, emaFast, atr);
   bool canUseLimit = InpUsePendingOrders && IsValidLimitPrice(dir, limitEntry);
   if(InpRequirePendingForWeakPA && pa.score < 5 && !canUseLimit)
      return EmptySignal();
   if(canUseLimit && (pa.score < 5 || BetterLimitThanMarket(dir, limitEntry)))
   {
      desiredEntry = limitEntry;
      execution = EXEC_LIMIT;
   }

   double invalidation = (dir == DIR_BUY)
                         ? MathMin(LowestLow(InpTriggerTf, 1, 5), emaSlow)
                         : MathMax(HighestHigh(InpTriggerTf, 1, 5), emaSlow);
   if(!CompleteSignalPrices(s, invalidation, desiredEntry))
      return EmptySignal();

   s.execution = execution;
   s.reason = StringFormat("regime=%s; zone=ema; distAtr=%.2f; pa=%s; %s",
                           regime.label, distanceAtr, pa.tags, ScoreBreakdown(s));
   s.valid = true;
   return s;
}

TradeSignal DetectLiquiditySweep(const Direction dir, const RegimeInfo &regime)
{
   TradeSignal s = EmptySignal();
   s.direction = dir;
   s.strategy = "LiquiditySweep";

   if(IsStrongOpposite(dir, regime.regime) && !InpAllowCounterTrendReversal)
      return s;

   SignalFeatures pa = AnalyzeTriggerPriceAction(dir);
   if(!(pa.sweep && pa.reclaim))
      return s;

   if(pa.score < InpMinSweepPaScore)
      return s;

   int setupScore = 13;
   int locationScore = 9 + (NearSupportResistance(dir, InpSetupTf) ? 4 : 0)
                         + (IsPriceStretched(dir) ? 2 : 0);
   locationScore = ClampInt(locationScore, 0, 15);

   ApplyScore(s, dir, regime, setupScore, locationScore, pa, "LiquiditySweep");
   if(IsStrongOpposite(dir, regime.regime))
      s.score = ClampInt(s.score - InpCounterTrendScoreBump, 0, 100);

   double invalidation = (dir == DIR_BUY)
                         ? iLow(TradeSymbol, InpTriggerTf, 1)
                         : iHigh(TradeSymbol, InpTriggerTf, 1);
   if(!CompleteSignalPrices(s, invalidation, CurrentEntryPrice(dir)))
      return EmptySignal();

   s.execution = EXEC_MARKET;
   s.reason = StringFormat("regime=%s; sweep_reclaim=true; pa=%s; %s",
                           regime.label, pa.tags, ScoreBreakdown(s));
   s.valid = true;
   return s;
}

TradeSignal DetectFvgRetracement(const Direction dir, const RegimeInfo &regime)
{
   TradeSignal s = EmptySignal();
   s.direction = dir;
   s.strategy = "FVGRetracement";

   if(IsStrongOpposite(dir, regime.regime))
      return s;

   double zoneLow = 0.0;
   double zoneHigh = 0.0;
   if(!FindActiveFvg(dir, zoneLow, zoneHigh))
      return s;

   SignalFeatures pa = AnalyzeTriggerPriceAction(dir);
   if(pa.score < InpMinFvgPaScore)
      return s;

   int setupScore = 12;
   int locationScore = 13 + (NearSupportResistance(dir, InpSetupTf) ? 2 : 0);
   locationScore = ClampInt(locationScore, 0, 15);

   ApplyScore(s, dir, regime, setupScore, locationScore, pa, "FVGRetracement");

   double desiredEntry = CurrentEntryPrice(dir);
   EntryExecution execution = EXEC_MARKET;
   double limitEntry = NormalizePrice((zoneLow + zoneHigh) * 0.5);
   bool canUseLimit = InpUsePendingOrders && IsValidLimitPrice(dir, limitEntry);
   if(InpRequirePendingForWeakPA && pa.score < 5 && !canUseLimit)
      return EmptySignal();
   if(canUseLimit && (pa.score < 5 || BetterLimitThanMarket(dir, limitEntry)))
   {
      desiredEntry = limitEntry;
      execution = EXEC_LIMIT;
   }

   double invalidation = (dir == DIR_BUY) ? zoneLow : zoneHigh;
   if(!CompleteSignalPrices(s, invalidation, desiredEntry))
      return EmptySignal();

   s.execution = execution;
   s.reason = StringFormat("regime=%s; fvg=%.2f-%.2f; pa=%s; %s",
                           regime.label, zoneLow, zoneHigh, pa.tags, ScoreBreakdown(s));
   s.valid = true;
   return s;
}

TradeSignal DetectBreakoutRetest(const Direction dir, const RegimeInfo &regime)
{
   TradeSignal s = EmptySignal();
   s.direction = dir;
   s.strategy = "BreakoutRetest";

   if(regime.regime != REGIME_COMPRESSION && regime.regime != REGIME_BREAKOUT &&
      regime.regime != REGIME_RANGE)
      return s;

   double atr = BufferValue(hAtrSetup, 0, 1);
   if(atr <= 0.0)
      return s;

   double rangeHigh = HighestHigh(InpSetupTf, 2, InpBreakoutLookback);
   double rangeLow = LowestLow(InpSetupTf, 2, InpBreakoutLookback);
   double close1 = iClose(TradeSymbol, InpSetupTf, 1);
   double price = CurrentEntryPrice(dir);

   bool breakout = false;
   bool retest = false;
   double boundary = 0.0;

   if(dir == DIR_BUY)
   {
      breakout = close1 > rangeHigh;
      boundary = rangeHigh;
      retest = price <= boundary + atr * 0.45 && price >= boundary - atr * 0.25;
   }
   else
   {
      breakout = close1 < rangeLow;
      boundary = rangeLow;
      retest = price >= boundary - atr * 0.45 && price <= boundary + atr * 0.25;
   }

   if(!breakout || !retest)
      return s;

   SignalFeatures pa = AnalyzeTriggerPriceAction(dir);
   if(pa.score < InpMinBreakoutPaScore)
      return s;

   int setupScore = 12;
   int locationScore = 12;
   ApplyScore(s, dir, regime, setupScore, locationScore, pa, "BreakoutRetest");

   double desiredEntry = CurrentEntryPrice(dir);
   EntryExecution execution = EXEC_MARKET;
   double stopEntry = BreakoutStopPrice(dir, atr);
   bool canUseStop = InpUsePendingOrders && IsValidStopPrice(dir, stopEntry);
   if(InpRequirePendingForWeakPA && pa.score < 4 && !canUseStop)
      return EmptySignal();
   if(canUseStop && (pa.score < 4 || BetterStopThanMarket(dir, stopEntry)))
   {
      desiredEntry = stopEntry;
      execution = EXEC_STOP;
   }

   double invalidation = (dir == DIR_BUY) ? boundary - atr * 0.25 : boundary + atr * 0.25;
   if(!CompleteSignalPrices(s, invalidation, desiredEntry))
      return EmptySignal();

   s.execution = execution;
   s.reason = StringFormat("regime=%s; boundary=%.2f; pa=%s; %s",
                           regime.label, boundary, pa.tags, ScoreBreakdown(s));
   s.valid = true;
   return s;
}

//+------------------------------------------------------------------+
//| Entry and risk                                                    |
//+------------------------------------------------------------------+
void TryOpenSignal(const TradeSignal &signal, const TradingState state)
{
   BasketInfo sameBasket;
   BasketInfo oppositeBasket;
   BuildBasket(signal.direction, sameBasket);
   BuildBasket(OppositeDirection(signal.direction), oppositeBasket);

   bool hasBasket = sameBasket.count > 0;
   bool isRecovery = hasBasket && sameBasket.floating < 0.0;
   bool isPyramid = hasBasket && sameBasket.floating >= 0.0;

   if(!StateAllowsEntry(state, hasBasket, isRecovery))
   {
      WriteJournal("REJECT_STATE", DirectionName(signal.direction), signal.strategy,
                   StateName(state), signal.score, signal.idealEntry, signal.sl, signal.tp,
                   0.0, 0.0, 0.0, 0.0, signal.reason);
      return;
   }

   if(!InpAllowHedgedBaskets && oppositeBasket.count > 0)
      return;

   if(!PassQualityGate(signal))
   {
      WriteJournal("REJECT_QUALITY_GATE", DirectionName(signal.direction), signal.strategy,
                   "", signal.score, signal.idealEntry, signal.sl, signal.tp,
                   0.0, 0.0, 0.0, 0.0, signal.reason,
                   ExecutionName(signal.execution), signal.orderPrice);
      return;
   }

   int requiredScore = RequiredScoreFor(signal, sameBasket, isRecovery, isPyramid);
   if(signal.score < requiredScore)
   {
      WriteJournal("REJECT_SCORE", DirectionName(signal.direction), signal.strategy,
                   "", signal.score, signal.idealEntry, signal.sl, signal.tp,
                   0.0, 0.0, 0.0, 0.0,
                   StringFormat("required=%d; %s", requiredScore, signal.reason));
      return;
   }

   if(sameBasket.count >= InpMaxPositionsPerBasket)
   {
      WriteJournal("REJECT_BASKET_COUNT", DirectionName(signal.direction), signal.strategy,
                   "", signal.score, signal.idealEntry, signal.sl, signal.tp,
                   0.0, 0.0, 0.0, 0.0, signal.reason);
      return;
   }

   if(isRecovery && IsBasketInvalidated(signal.direction, DetectRegime()))
   {
      WriteJournal("REJECT_INVALIDATED", DirectionName(signal.direction), signal.strategy,
                   "", signal.score, signal.idealEntry, signal.sl, signal.tp,
                   0.0, 0.0, 0.0, 0.0, signal.reason);
      return;
   }

   if(!ExecutionGuard(signal, sameBasket))
      return;

   double lot = CalculateLot(signal, sameBasket, isRecovery, isPyramid);
   if(lot <= 0.0)
   {
      WriteJournal("REJECT_LOT", DirectionName(signal.direction), signal.strategy,
                   "", signal.score, signal.idealEntry, signal.sl, signal.tp,
                   lot, 0.0, 0.0, 0.0, signal.reason);
      return;
   }

   if(!ExposureGuard(signal, lot, sameBasket))
      return;

   string comment = StringFormat("Lambo|%s|%s|%d",
                                 ShortStrategyName(signal.strategy),
                                 ExecutionName(signal.execution),
                                 signal.score);
   ResetLastError();
   bool ok = SubmitSignalOrder(signal, lot, comment);

   double retcode = (double)Trade.ResultRetcode();
   string resultText = Trade.ResultRetcodeDescription();

   if(ok)
   {
      datetime bar = iTime(TradeSymbol, InpTriggerTf, 0);
      if(signal.direction == DIR_BUY)
         g_lastBuyEntryBar = bar;
      else
         g_lastSellEntryBar = bar;
      WriteJournal((isRecovery ? "ENTRY_RECOVERY" : (isPyramid ? "ENTRY_PYRAMID" : "ENTRY")),
                   DirectionName(signal.direction), signal.strategy, RegimeName(DetectRegime().regime),
                   signal.score, signal.idealEntry, signal.sl, signal.tp, lot,
                   signal.rr, SpreadPoints(), 0.0, signal.reason,
                   ExecutionName(signal.execution), signal.orderPrice);
   }
   else
   {
      WriteJournal("ORDER_FAILED", DirectionName(signal.direction), signal.strategy,
                   resultText, signal.score, signal.idealEntry, signal.sl, signal.tp,
                   lot, signal.rr, SpreadPoints(), retcode, signal.reason,
                   ExecutionName(signal.execution), signal.orderPrice);
   }
}

bool SubmitSignalOrder(const TradeSignal &signal,
                       const double lot,
                       const string comment)
{
   if(signal.execution == EXEC_LIMIT)
   {
      ENUM_ORDER_TYPE_TIME timeType = ORDER_TIME_GTC;
      datetime expiration = 0;
      if(InpPendingExpiryBars > 0)
      {
         timeType = ORDER_TIME_SPECIFIED;
         expiration = PendingExpiryTime();
      }

      if(signal.direction == DIR_BUY)
         return Trade.BuyLimit(lot, signal.orderPrice, TradeSymbol,
                               signal.sl, signal.tp, timeType, expiration, comment);
      if(signal.direction == DIR_SELL)
         return Trade.SellLimit(lot, signal.orderPrice, TradeSymbol,
                                signal.sl, signal.tp, timeType, expiration, comment);
   }
   else if(signal.execution == EXEC_STOP)
   {
      ENUM_ORDER_TYPE_TIME timeType = ORDER_TIME_GTC;
      datetime expiration = 0;
      if(InpPendingExpiryBars > 0)
      {
         timeType = ORDER_TIME_SPECIFIED;
         expiration = PendingExpiryTime();
      }

      if(signal.direction == DIR_BUY)
         return Trade.BuyStop(lot, signal.orderPrice, TradeSymbol,
                              signal.sl, signal.tp, timeType, expiration, comment);
      if(signal.direction == DIR_SELL)
         return Trade.SellStop(lot, signal.orderPrice, TradeSymbol,
                               signal.sl, signal.tp, timeType, expiration, comment);
   }

   if(signal.direction == DIR_BUY)
      return Trade.Buy(lot, TradeSymbol, 0.0, signal.sl, signal.tp, comment);
   if(signal.direction == DIR_SELL)
      return Trade.Sell(lot, TradeSymbol, 0.0, signal.sl, signal.tp, comment);

   return false;
}

datetime PendingExpiryTime()
{
   int seconds = PeriodSeconds(InpTriggerTf);
   if(seconds <= 0)
      seconds = 120;
   return TimeCurrent() + seconds * MathMax(1, InpPendingExpiryBars);
}

bool ExecutionGuard(const TradeSignal &signal, const BasketInfo &sameBasket)
{
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      return false;

   double spread = SpreadPoints();
   int maxSpread = EffectiveMaxSpreadPoints();
   if(spread > maxSpread)
   {
      WriteJournal("REJECT_SPREAD", DirectionName(signal.direction), signal.strategy, "",
                   signal.score, signal.idealEntry, signal.sl, signal.tp,
                   0.0, signal.rr, spread, 0.0,
                   StringFormat("spread=%.1f; max=%d; %s", spread, maxSpread, signal.reason));
      return false;
   }

   if(InpHardSessionFilter && !IsInAllowedSession())
   {
      WriteJournal("REJECT_SESSION", DirectionName(signal.direction), signal.strategy, "",
                   signal.score, signal.idealEntry, signal.sl, signal.tp,
                   0.0, signal.rr, SpreadPoints(), 0.0, signal.reason);
      return false;
   }

   double atr = BufferValue(hAtrTrigger, 0, 1);
   double price = CurrentEntryPrice(signal.direction);
   if(signal.execution == EXEC_MARKET && atr > 0.0 &&
      MathAbs(price - signal.idealEntry) > atr * InpMaxEntryAtrDeviation)
   {
      WriteJournal("REJECT_CHASE", DirectionName(signal.direction), signal.strategy, "",
                   signal.score, signal.idealEntry, signal.sl, signal.tp,
                   0.0, signal.rr, SpreadPoints(), 0.0,
                   StringFormat("price=%.2f; %s", price, signal.reason),
                   ExecutionName(signal.execution), signal.orderPrice);
      return false;
   }

   if(signal.execution != EXEC_MARKET)
   {
      if(CountOwnedPendingOrders(DIR_NONE) >= InpMaxPendingOrders)
      {
         WriteJournal("REJECT_PENDING_LIMIT", DirectionName(signal.direction), signal.strategy, "",
                      signal.score, signal.idealEntry, signal.sl, signal.tp,
                      0.0, signal.rr, SpreadPoints(), 0.0, signal.reason,
                      ExecutionName(signal.execution), signal.orderPrice);
         return false;
      }

      if(!PendingPriceGuard(signal))
      {
         WriteJournal("REJECT_PENDING_PRICE", DirectionName(signal.direction), signal.strategy, "",
                      signal.score, signal.idealEntry, signal.sl, signal.tp,
                      0.0, signal.rr, SpreadPoints(), 0.0, signal.reason,
                      ExecutionName(signal.execution), signal.orderPrice);
         return false;
      }

      if(HasNearPendingOrder(signal))
      {
         WriteJournal("REJECT_DUP_PENDING", DirectionName(signal.direction), signal.strategy, "",
                      signal.score, signal.idealEntry, signal.sl, signal.tp,
                      0.0, signal.rr, SpreadPoints(), 0.0, signal.reason,
                      ExecutionName(signal.execution), signal.orderPrice);
         return false;
      }
   }

   if(sameBasket.count > 0)
   {
      double spacing = MathAbs(SignalEntryPrice(signal) - sameBasket.lastEntryPrice);
      double minSpacing = BufferValue(hAtrSetup, 0, 1) * InpMinReentrySpacingAtr;
      if(minSpacing > 0.0 && spacing < minSpacing)
      {
         WriteJournal("REJECT_SPACING", DirectionName(signal.direction), signal.strategy, "",
                      signal.score, signal.idealEntry, signal.sl, signal.tp,
                      0.0, signal.rr, SpreadPoints(), 0.0,
                      StringFormat("spacing=%.2f; min=%.2f; %s", spacing, minSpacing, signal.reason));
         return false;
      }
   }

   if(TradesLastHour() >= InpMaxTradesPerHour)
      return false;

   if(ConsecutiveLosses() >= InpMaxConsecutiveLosses)
      return false;

   return true;
}

double CalculateLot(const TradeSignal &signal,
                    const BasketInfo &sameBasket,
                    const bool isRecovery,
                    const bool isPyramid)
{
   double lot = InpFixedLot;
   if(InpLotMode != LOT_FIXED)
   {
      double entry = SignalEntryPrice(signal);
      double stopDistance = MathAbs(entry - signal.sl);
      double riskPerLot = MoneyRiskPerLot(stopDistance);
      if(riskPerLot <= 0.0)
         return 0.0;

      double baseRiskPct = InpRiskPerTradePct;
      double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * baseRiskPct / 100.0;
      riskMoney *= ScoreLotModifier(signal.score);

      if(InpLotMode == LOT_SMART)
      {
         riskMoney *= DrawdownLotModifier();
         riskMoney *= VolatilityLotModifier();
         riskMoney *= ExposureLotModifier();
      }

      lot = riskMoney / riskPerLot;
   }

   if(isRecovery)
   {
      lot *= (1.0 + InpRecoveryLotAddPct * sameBasket.count / 100.0);
      lot = MathMin(lot, InpMaxReentryLot);
   }
   else if(isPyramid)
   {
      lot *= MathPow(MathMax(0.10, InpPyramidLotFactor), sameBasket.count);
      lot = MathMin(lot, InpMaxReentryLot);
   }
   else
   {
      lot = MathMin(lot, InpMaxInitialLot);
   }

   lot = NormalizeVolume(lot);

   if(lot <= 0.0 && InpAllowMinLotWhenRiskSmall)
      lot = NormalizeVolume(MinBrokerLot());

   return lot;
}

bool ExposureGuard(const TradeSignal &signal, const double newLot, const BasketInfo &sameBasket)
{
   BasketInfo buyBasket;
   BasketInfo sellBasket;
   BuildBasket(DIR_BUY, buyBasket);
   BuildBasket(DIR_SELL, sellBasket);
   double totalLots = buyBasket.lots + sellBasket.lots + PendingOrderLots(DIR_NONE);
   if(totalLots + newLot > InpMaxTotalLot)
      return false;

   if(sameBasket.lots + PendingOrderLots(signal.direction) + newLot > InpMaxBasketLot)
      return false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > 0.0 && InpMaxBasketRiskPct > 0.0)
   {
      // Approximate added hard risk from the new order. Existing floating loss is
      // included so recovery cannot keep increasing exposure after a bad thesis.
      double stopDistance = MathAbs(SignalEntryPrice(signal) - signal.sl);
      double riskMoney = MoneyRiskPerLot(stopDistance) * newLot + MathMax(0.0, -sameBasket.floating);
      double riskPct = riskMoney / equity * 100.0;
      if(riskPct > InpMaxBasketRiskPct)
         return false;
   }

   return true;
}

int RequiredScoreFor(const TradeSignal &signal,
                     const BasketInfo &basket,
                     const bool isRecovery,
                     const bool isPyramid)
{
   int required = InpMinEntryScore;

   if(basket.count <= 0)
   {
      if(InpUseAdaptiveEntryThreshold)
      {
         if(signal.contextScore >= 13 && signal.structureScore >= 10 && signal.paScore >= 5)
            required -= InpAlignedContextDiscount;
         if(signal.strategy == "LiquiditySweep" && signal.contextScore >= 13)
            required -= InpRangeSweepDiscount;
         if(signal.contextScore <= 5)
            required += InpWeakContextPenalty;
         if(signal.volatilityScore <= 2)
            required += InpHighVolatilityPenalty;
      }
      return ClampInt(required, InpMinAdaptiveEntryScore, 95);
   }

   if(isRecovery)
   {
      required = InpMinRecoveryScore + MathMax(0, basket.count - 1) * InpRecoveryScoreStep;
      if(signal.contextScore <= 5)
         required += InpWeakContextPenalty;
      if(signal.volatilityScore <= 2)
         required += InpHighVolatilityPenalty;
      return ClampInt(required, InpMinRecoveryScore, 98);
   }

   if(isPyramid)
   {
      required = InpMinPyramidScore;
      if(signal.contextScore <= 8)
         required += InpWeakContextPenalty;
      return ClampInt(required, InpMinPyramidScore, 95);
   }

   return InpMinEntryScore;
}

bool PassQualityGate(const TradeSignal &signal)
{
   if(signal.contextScore <= 0 || signal.volatilityScore <= 0)
      return false;

   if(signal.locationScore < InpMinLocationScore)
      return false;

   if(signal.strategy == "LiquiditySweep" && signal.paScore < InpMinSweepPaScore)
      return false;
   if(signal.strategy == "TrendPullback" && signal.paScore < InpMinPullbackPaScore)
      return false;
   if(signal.strategy == "FVGRetracement" && signal.paScore < InpMinFvgPaScore)
      return false;
   if(signal.strategy == "BreakoutRetest" && signal.paScore < InpMinBreakoutPaScore)
      return false;

   if(InpRequirePendingForWeakPA && signal.execution == EXEC_MARKET)
   {
      if(signal.strategy == "TrendPullback" && signal.paScore < 5)
         return false;
      if(signal.strategy == "FVGRetracement" && signal.paScore < 5)
         return false;
      if(signal.strategy == "BreakoutRetest" && signal.paScore < 4)
         return false;
   }

   return true;
}

bool StateAllowsEntry(const TradingState state,
                      const bool hasBasket,
                      const bool isRecovery)
{
   if(state == STATE_RUNNING)
      return true;
   if(state == STATE_RECOVERY_ONLY)
      return hasBasket && isRecovery;
   return false;
}

TradingState EffectiveTradingState(const BasketInfo &buyBasket,
                                   const BasketInfo &sellBasket)
{
   if(InpManualState != STATE_RUNNING)
      return InpManualState;

   double dd = CurrentDrawdownPct();
   double floating = buyBasket.floating + sellBasket.floating;
   double marginUsage = MarginUsagePct();

   if(dd >= InpEmergencyDrawdownPct)
      return STATE_EMERGENCY;
   if(dd >= InpMaxDrawdownPct)
      return STATE_NO_NEW_ENTRY;
   if(dd >= InpRecoveryOnlyDdPct)
      return STATE_RECOVERY_ONLY;
   if(InpMaxFloatingLossMoney > 0.0 && floating <= -InpMaxFloatingLossMoney)
      return STATE_NO_NEW_ENTRY;
   if(InpMaxBasketLossMoney > 0.0 &&
      (buyBasket.floating <= -InpMaxBasketLossMoney || sellBasket.floating <= -InpMaxBasketLossMoney))
      return STATE_NO_NEW_ENTRY;
   if(marginUsage >= InpMaxMarginUsagePct)
      return STATE_NO_NEW_ENTRY;
   if(ConsecutiveLosses() >= InpMaxConsecutiveLosses)
      return STATE_NO_NEW_ENTRY;

   return STATE_RUNNING;
}

//+------------------------------------------------------------------+
//| Basket management                                                 |
//+------------------------------------------------------------------+
void ManageBaskets(const RegimeInfo &regime,
                   const BasketInfo &buyBasket,
                   const BasketInfo &sellBasket)
{
   if(InpUseBasketTrailing)
   {
      ManageBasketTrailing(DIR_BUY, buyBasket);
      ManageBasketTrailing(DIR_SELL, sellBasket);
   }

   if(InpCloseInvalidatedBasket)
   {
      if(buyBasket.count > 0 && buyBasket.floating < 0.0 && IsBasketInvalidated(DIR_BUY, regime))
         CloseBasket(DIR_BUY, "BUY_INVALIDATED");
      if(sellBasket.count > 0 && sellBasket.floating < 0.0 && IsBasketInvalidated(DIR_SELL, regime))
         CloseBasket(DIR_SELL, "SELL_INVALIDATED");
   }

   if(InpUseCrossBasketNetExit && buyBasket.count > 0 && sellBasket.count > 0)
   {
      double net = buyBasket.floating + sellBasket.floating;
      double buyAbs = MathAbs(buyBasket.floating);
      double sellAbs = MathAbs(sellBasket.floating);
      bool enoughOffset = false;

      if(buyBasket.floating > 0.0 && sellBasket.floating < 0.0)
         enoughOffset = buyBasket.floating >= sellAbs * InpCrossBasketOffsetRatio;
      if(sellBasket.floating > 0.0 && buyBasket.floating < 0.0)
         enoughOffset = sellBasket.floating >= buyAbs * InpCrossBasketOffsetRatio;

      if(net >= InpCrossBasketNetTargetMoney && enoughOffset)
         CloseAllOwnedPositions("CROSS_BASKET_NET_EXIT");
   }
}

void ManagePendingOrders(const RegimeInfo &regime)
{
   if(!InpCancelInvalidPending)
      return;

   double atr = BufferValue(hAtrSetup, 0, 1);
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) != TradeSymbol)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber)
         continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!IsPendingOrderType(type))
         continue;

      Direction dir = PendingOrderDirection(type);
      double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      double volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
      double current = CurrentEntryPrice(dir);
      bool invalidRegime = IsStrongOpposite(dir, regime.regime);
      bool tooFar = atr > 0.0 &&
                    MathAbs(orderPrice - current) > atr * InpMaxPendingAtrDistance;

      if(invalidRegime || tooFar)
      {
         string reason = invalidRegime ? "pending_regime_invalid" : "pending_too_far";
         ResetLastError();
         bool deleted = Trade.OrderDelete(ticket);
         WriteJournal(deleted ? "CANCEL_PENDING" : "CANCEL_PENDING_FAILED",
                      DirectionName(dir), "", regime.label, 0,
                      current, 0.0, 0.0, volume, 0.0, SpreadPoints(),
                      (double)Trade.ResultRetcode(), reason,
                      PendingTypeName(type), orderPrice);
      }
   }
}

void ManageBasketTrailing(const Direction dir, const BasketInfo &basket)
{
   string activeKey = GvKey(DirectionName(dir) + "_TrailActive");
   string protectedKey = GvKey(DirectionName(dir) + "_TrailProtected");

   if(basket.count <= 0)
   {
      GlobalVariableSet(activeKey, 0.0);
      GlobalVariableSet(protectedKey, 0.0);
      return;
   }

   bool active = GlobalVariableCheck(activeKey) && GlobalVariableGet(activeKey) > 0.5;
   double protectedProfit = (GlobalVariableCheck(protectedKey) ? GlobalVariableGet(protectedKey) : 0.0);

   if(!active && basket.floating >= InpBasketTrailStartMoney)
   {
      active = true;
      protectedProfit = MathMax(InpBasketTrailLockMoney,
                                basket.floating - InpBasketTrailGivebackMoney);
      GlobalVariableSet(activeKey, 1.0);
      GlobalVariableSet(protectedKey, protectedProfit);
   }
   else if(active)
   {
      double nextProtected = MathMax(protectedProfit,
                                     basket.floating - InpBasketTrailGivebackMoney);
      if(nextProtected > protectedProfit)
      {
         protectedProfit = nextProtected;
         GlobalVariableSet(protectedKey, protectedProfit);
      }

      if(basket.floating <= protectedProfit)
         CloseBasket(dir, "BASKET_TRAILING");
   }
}

bool IsBasketInvalidated(const Direction dir, const RegimeInfo &regime)
{
   double emaFast = BufferValue(hEmaFastSetup, 0, 1);
   double emaSlow = BufferValue(hEmaSlowSetup, 0, 1);
   double adx = BufferValue(hAdxSetup, 0, 1);

   if(dir == DIR_BUY)
   {
      bool contextFlip = regime.regime == REGIME_DOWNTREND ||
                         regime.regime == REGIME_STRONG_DOWNTREND;
      bool setupFlip = emaFast < emaSlow && StructureScore(DIR_SELL, InpSetupTf) >= 10;
      return contextFlip && setupFlip && adx >= InpTrendAdx;
   }

   if(dir == DIR_SELL)
   {
      bool contextFlip = regime.regime == REGIME_UPTREND ||
                         regime.regime == REGIME_STRONG_UPTREND;
      bool setupFlip = emaFast > emaSlow && StructureScore(DIR_BUY, InpSetupTf) >= 10;
      return contextFlip && setupFlip && adx >= InpTrendAdx;
   }

   return false;
}

void BuildBasket(const Direction dir, BasketInfo &basket)
{
   basket.count = 0;
   basket.lots = 0.0;
   basket.avgPrice = 0.0;
   basket.floating = 0.0;
   basket.weightedPrice = 0.0;
   basket.lastEntryPrice = 0.0;
   basket.lastEntryTime = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != TradeSymbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      long type = PositionGetInteger(POSITION_TYPE);
      Direction posDir = (type == POSITION_TYPE_BUY ? DIR_BUY : DIR_SELL);
      if(posDir != dir)
         continue;

      double volume = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

      basket.count++;
      basket.lots += volume;
      basket.weightedPrice += openPrice * volume;
      basket.floating += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      if(openTime >= basket.lastEntryTime)
      {
         basket.lastEntryTime = openTime;
         basket.lastEntryPrice = openPrice;
      }
   }

   if(basket.lots > 0.0)
      basket.avgPrice = basket.weightedPrice / basket.lots;
}

void CloseBasket(const Direction dir, const string reason)
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != TradeSymbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      long type = PositionGetInteger(POSITION_TYPE);
      Direction posDir = (type == POSITION_TYPE_BUY ? DIR_BUY : DIR_SELL);
      if(posDir != dir)
         continue;

      Trade.PositionClose(ticket);
   }

   WriteJournal("CLOSE_BASKET", DirectionName(dir), "", "", 0, 0.0, 0.0, 0.0,
                0.0, 0.0, SpreadPoints(), 0.0, reason);
}

void CloseAllOwnedPositions(const string reason)
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != TradeSymbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      Trade.PositionClose(ticket);
   }

   WriteJournal("CLOSE_ALL", "", "", "", 0, 0.0, 0.0, 0.0,
                0.0, 0.0, SpreadPoints(), 0.0, reason);
}

//+------------------------------------------------------------------+
//| MAE/MFE tracking                                                  |
//+------------------------------------------------------------------+
void UpdatePositionExcursions()
{
   if(!InpTrackMaeMfe)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != TradeSymbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      ulong positionId = SelectedPositionId(ticket);
      double floating = PositionFloatingMoney();
      string maeKey = PositionExcursionKey("MAE", positionId);
      string mfeKey = PositionExcursionKey("MFE", positionId);

      double maeMoney = floating;
      double mfeMoney = floating;
      if(GlobalVariableCheck(maeKey))
         maeMoney = GlobalVariableGet(maeKey);
      if(GlobalVariableCheck(mfeKey))
         mfeMoney = GlobalVariableGet(mfeKey);

      if(floating < maeMoney)
         maeMoney = floating;
      if(floating > mfeMoney)
         mfeMoney = floating;

      GlobalVariableSet(maeKey, maeMoney);
      GlobalVariableSet(mfeKey, mfeMoney);
   }
}

void SeedPositionExcursion(const ulong positionId)
{
   if(!InpTrackMaeMfe || positionId == 0)
      return;

   double floating = 0.0;
   if(!FindOpenPositionFloating(positionId, floating))
      floating = 0.0;

   string maeKey = PositionExcursionKey("MAE", positionId);
   string mfeKey = PositionExcursionKey("MFE", positionId);
   if(!GlobalVariableCheck(maeKey))
      GlobalVariableSet(maeKey, floating);
   if(!GlobalVariableCheck(mfeKey))
      GlobalVariableSet(mfeKey, floating);
}

void ReadPositionExcursions(const ulong positionId, double &maeMoney, double &mfeMoney)
{
   maeMoney = 0.0;
   mfeMoney = 0.0;
   if(!InpTrackMaeMfe || positionId == 0)
      return;

   string maeKey = PositionExcursionKey("MAE", positionId);
   string mfeKey = PositionExcursionKey("MFE", positionId);
   if(GlobalVariableCheck(maeKey))
      maeMoney = GlobalVariableGet(maeKey);
   if(GlobalVariableCheck(mfeKey))
      mfeMoney = GlobalVariableGet(mfeKey);
}

void DeletePositionExcursions(const ulong positionId)
{
   if(positionId == 0)
      return;

   GlobalVariableDel(PositionExcursionKey("MAE", positionId));
   GlobalVariableDel(PositionExcursionKey("MFE", positionId));
   GlobalVariableDel(PositionExcursionKey("STR", positionId));
}

void StorePositionStrategyCode(const ulong positionId, const string strategyCode)
{
   if(positionId == 0)
      return;

   int strategyId = StrategyIdFromCode(strategyCode);
   if(strategyId <= 0)
      return;

   GlobalVariableSet(PositionExcursionKey("STR", positionId), (double)strategyId);
}

string PositionStrategyCode(const ulong positionId)
{
   if(positionId == 0)
      return "";

   string key = PositionExcursionKey("STR", positionId);
   if(!GlobalVariableCheck(key))
      return "";

   int strategyId = (int)MathRound(GlobalVariableGet(key));
   return StrategyCodeFromId(strategyId);
}

bool PositionIdStillOpen(const ulong positionId)
{
   double floating = 0.0;
   return FindOpenPositionFloating(positionId, floating);
}

bool FindOpenPositionFloating(const ulong positionId, double &floating)
{
   floating = 0.0;
   if(positionId == 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != TradeSymbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      if(SelectedPositionId(ticket) != positionId)
         continue;

      floating = PositionFloatingMoney();
      return true;
   }

   return false;
}

double PositionFloatingMoney()
{
   return PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
}

ulong SelectedPositionId(const ulong ticket)
{
   long identifier = PositionGetInteger(POSITION_IDENTIFIER);
   if(identifier > 0)
      return (ulong)identifier;
   return ticket;
}

string PositionExcursionKey(const string metric, const ulong positionId)
{
   return GvKey(metric + "_" + UlongToString(positionId));
}

//+------------------------------------------------------------------+
//| Regime and scoring                                                |
//+------------------------------------------------------------------+
RegimeInfo DetectRegime()
{
   RegimeInfo r;
   r.regime = REGIME_UNKNOWN;
   r.emaFast = BufferValue(hEmaFastContext, 0, 1);
   r.emaSlow = BufferValue(hEmaSlowContext, 0, 1);
   r.atr = BufferValue(hAtrContext, 0, 1);
   r.adx = BufferValue(hAdxContext, 0, 1);
   r.label = "UNKNOWN";

   if(r.atr <= 0.0)
      return r;

   double emaFast4 = BufferValue(hEmaFastContext, 0, 4);
   double bandsUpper = BufferValue(hBandsContext, 1, 1);
   double bandsLower = BufferValue(hBandsContext, 2, 1);
   double atrAvg = AverageBuffer(hAtrContext, 0, 2, 50);
   if(atrAvg <= 0.0)
      atrAvg = r.atr;

   r.emaGapAtr = (r.emaFast - r.emaSlow) / r.atr;
   r.emaSlopeAtr = (r.emaFast - emaFast4) / r.atr;
   r.atrRatio = r.atr / atrAvg;
   r.bbWidthAtr = (bandsUpper - bandsLower) / r.atr;

   if(r.atrRatio >= InpChaoticAtrRatio && r.adx < InpTrendAdx)
      r.regime = REGIME_CHAOTIC;
   else if(r.atrRatio >= InpHighVolAtrRatio)
      r.regime = REGIME_HIGH_VOLATILITY;
   else if(r.bbWidthAtr <= InpCompressionBbAtr && r.atrRatio <= InpCompressionAtrRatio)
      r.regime = REGIME_COMPRESSION;
   else if(r.emaGapAtr > 0.40 && r.emaSlopeAtr > 0.06 && r.adx >= InpStrongTrendAdx)
      r.regime = REGIME_STRONG_UPTREND;
   else if(r.emaGapAtr > 0.12 && r.adx >= InpTrendAdx)
      r.regime = REGIME_UPTREND;
   else if(r.emaGapAtr < -0.40 && r.emaSlopeAtr < -0.06 && r.adx >= InpStrongTrendAdx)
      r.regime = REGIME_STRONG_DOWNTREND;
   else if(r.emaGapAtr < -0.12 && r.adx >= InpTrendAdx)
      r.regime = REGIME_DOWNTREND;
   else
      r.regime = REGIME_RANGE;

   r.label = RegimeName(r.regime);
   return r;
}

int BuildScore(const Direction dir,
               const RegimeInfo &regime,
               const int setupScore,
               const int locationScore,
               const SignalFeatures &pa,
               const string strategy)
{
   int score = 0;
   score += DirectionContextScore(dir, regime.regime, strategy);       // 0..15
   score += StructureScore(dir, InpSetupTf);                           // 0..15
   score += ClampInt(setupScore, 0, 15);                               // 0..15
   score += ClampInt(locationScore, 0, 15);                            // 0..15
   score += ClampInt(pa.score, 0, 15);                                 // 0..15
   score += MomentumScore(dir);                                        // 0..10
   score += VolatilityScore(regime);                                   // 0..5
   score += SpreadScore();                                             // 0..5
   score += SessionScore();                                            // 0..5
   return ClampInt(score, 0, 100);
}

void ApplyScore(TradeSignal &signal,
                const Direction dir,
                const RegimeInfo &regime,
                const int setupScore,
                const int locationScore,
                const SignalFeatures &pa,
                const string strategy)
{
   signal.contextScore = DirectionContextScore(dir, regime.regime, strategy);
   signal.structureScore = StructureScore(dir, InpSetupTf);
   signal.setupScore = ClampInt(setupScore, 0, 15);
   signal.locationScore = ClampInt(locationScore, 0, 15);
   signal.paScore = ClampInt(pa.score, 0, 15);
   signal.momentumScore = MomentumScore(dir);
   signal.volatilityScore = VolatilityScore(regime);
   signal.spreadScore = SpreadScore();
   signal.sessionScore = SessionScore();

   signal.score = ClampInt(signal.contextScore +
                           signal.structureScore +
                           signal.setupScore +
                           signal.locationScore +
                           signal.paScore +
                           signal.momentumScore +
                           signal.volatilityScore +
                           signal.spreadScore +
                           signal.sessionScore, 0, 100);
}

string ScoreBreakdown(const TradeSignal &signal)
{
   return StringFormat("scores=ctx:%d,str:%d,set:%d,loc:%d,pa:%d,mom:%d,vol:%d,spr:%d,ses:%d,total:%d",
                       signal.contextScore,
                       signal.structureScore,
                       signal.setupScore,
                       signal.locationScore,
                       signal.paScore,
                       signal.momentumScore,
                       signal.volatilityScore,
                       signal.spreadScore,
                       signal.sessionScore,
                       signal.score);
}

int DirectionContextScore(const Direction dir,
                          const MarketRegime regime,
                          const string strategy)
{
   if(regime == REGIME_CHAOTIC)
      return 0;

   if(strategy == "BreakoutRetest" &&
      (regime == REGIME_COMPRESSION || regime == REGIME_BREAKOUT || regime == REGIME_RANGE))
      return 13;

   if(strategy == "LiquiditySweep" && regime == REGIME_RANGE)
      return 13;

   if(dir == DIR_BUY)
   {
      if(regime == REGIME_STRONG_UPTREND) return 15;
      if(regime == REGIME_UPTREND) return 13;
      if(regime == REGIME_RANGE || regime == REGIME_COMPRESSION) return 8;
      if(regime == REGIME_HIGH_VOLATILITY) return 5;
      return 2;
   }

   if(dir == DIR_SELL)
   {
      if(regime == REGIME_STRONG_DOWNTREND) return 15;
      if(regime == REGIME_DOWNTREND) return 13;
      if(regime == REGIME_RANGE || regime == REGIME_COMPRESSION) return 8;
      if(regime == REGIME_HIGH_VOLATILITY) return 5;
      return 2;
   }

   return 0;
}

int StructureScore(const Direction dir, const ENUM_TIMEFRAMES tf)
{
   double recentHigh = HighestHigh(tf, 1, InpStructureLookback);
   double recentLow = LowestLow(tf, 1, InpStructureLookback);
   double previousHigh = HighestHigh(tf, InpStructureLookback + 1, InpStructureLookback);
   double previousLow = LowestLow(tf, InpStructureLookback + 1, InpStructureLookback);

   if(recentHigh == 0.0 || recentLow == 0.0 || previousHigh == 0.0 || previousLow == 0.0)
      return 0;

   if(dir == DIR_BUY)
   {
      if(recentHigh > previousHigh && recentLow > previousLow) return 15;
      if(recentHigh > previousHigh || recentLow > previousLow) return 10;
   }
   else if(dir == DIR_SELL)
   {
      if(recentHigh < previousHigh && recentLow < previousLow) return 15;
      if(recentHigh < previousHigh || recentLow < previousLow) return 10;
   }

   return 4;
}

int MomentumScore(const Direction dir)
{
   int score = 0;
   double rsi = BufferValue(hRsiTrigger, 0, 1);
   double emaNow = BufferValue(hEmaFastTrigger, 0, 1);
   double emaPrev = BufferValue(hEmaFastTrigger, 0, 4);
   double plusDi = BufferValue(hAdxSetup, 1, 1);
   double minusDi = BufferValue(hAdxSetup, 2, 1);

   if(dir == DIR_BUY)
   {
      if(rsi >= 48.0 && rsi <= 72.0) score += 4;
      if(emaNow > emaPrev) score += 3;
      if(plusDi > minusDi) score += 3;
   }
   else if(dir == DIR_SELL)
   {
      if(rsi <= 52.0 && rsi >= 28.0) score += 4;
      if(emaNow < emaPrev) score += 3;
      if(minusDi > plusDi) score += 3;
   }

   return ClampInt(score, 0, 10);
}

int VolatilityScore(const RegimeInfo &regime)
{
   if(regime.regime == REGIME_CHAOTIC)
      return 0;
   if(regime.atrRatio > InpHighVolAtrRatio)
      return 2;
   if(regime.atrRatio < 0.55)
      return 2;
   return 5;
}

int SpreadScore()
{
   double spread = SpreadPoints();
   int maxSpread = EffectiveMaxSpreadPoints();
   if(spread <= maxSpread * 0.50)
      return 5;
   if(spread <= maxSpread)
      return 3;
   return 0;
}

int EffectiveMaxSpreadPoints()
{
   int configured = MathMax(1, InpMaxSpreadPoints);
   if(!InpUseAdaptiveSpreadLimit)
      return configured;

   long brokerSpread = SymbolInfoInteger(TradeSymbol, SYMBOL_SPREAD);
   if(brokerSpread <= 0)
      return configured;

   int cap = MathMax(configured, InpAdaptiveSpreadCapPoints);
   int adaptive = (int)MathRound((double)brokerSpread * MathMax(1.0, InpSpreadLimitMultiplier));
   return ClampInt(adaptive, configured, cap);
}

int SessionScore()
{
   if(!InpUseSessionScore)
      return 5;
   return IsInAllowedSession() ? 5 : 1;
}

//+------------------------------------------------------------------+
//| Price action and strategy helpers                                 |
//+------------------------------------------------------------------+
SignalFeatures AnalyzeTriggerPriceAction(const Direction dir)
{
   SignalFeatures f;
   f.sweep = false;
   f.reclaim = false;
   f.choch = false;
   f.engulfing = false;
   f.pinbar = false;
   f.rejection = false;
   f.score = 0;
   f.tags = "";

   double o1 = iOpen(TradeSymbol, InpTriggerTf, 1);
   double c1 = iClose(TradeSymbol, InpTriggerTf, 1);
   double h1 = iHigh(TradeSymbol, InpTriggerTf, 1);
   double l1 = iLow(TradeSymbol, InpTriggerTf, 1);
   double o2 = iOpen(TradeSymbol, InpTriggerTf, 2);
   double c2 = iClose(TradeSymbol, InpTriggerTf, 2);
   if(o1 == 0.0 || c1 == 0.0 || h1 == 0.0 || l1 == 0.0)
      return f;

   double body = MathMax(MathAbs(c1 - o1), PointValue());
   double upperWick = h1 - MathMax(o1, c1);
   double lowerWick = MathMin(o1, c1) - l1;

   if(dir == DIR_BUY)
   {
      double priorLow = LowestLow(InpTriggerTf, 2, InpSweepLookback);
      double priorHigh = HighestHigh(InpTriggerTf, 2, InpChochLookback);
      f.sweep = (priorLow > 0.0 && l1 < priorLow);
      f.reclaim = (priorLow > 0.0 && c1 > priorLow && c1 > o1);
      f.choch = (priorHigh > 0.0 && c1 > priorHigh);
      f.engulfing = (c1 > o1 && o1 <= c2 && c1 >= o2);
      f.pinbar = (lowerWick >= body * 1.5 && lowerWick > upperWick);
      f.rejection = (c1 > o1 && lowerWick >= body);
   }
   else if(dir == DIR_SELL)
   {
      double priorHigh = HighestHigh(InpTriggerTf, 2, InpSweepLookback);
      double priorLow = LowestLow(InpTriggerTf, 2, InpChochLookback);
      f.sweep = (priorHigh > 0.0 && h1 > priorHigh);
      f.reclaim = (priorHigh > 0.0 && c1 < priorHigh && c1 < o1);
      f.choch = (priorLow > 0.0 && c1 < priorLow);
      f.engulfing = (c1 < o1 && o1 >= c2 && c1 <= o2);
      f.pinbar = (upperWick >= body * 1.5 && upperWick > lowerWick);
      f.rejection = (c1 < o1 && upperWick >= body);
   }

   if(f.sweep && f.reclaim) { f.score += 7; AppendTag(f.tags, "sweep_reclaim"); }
   if(f.choch)             { f.score += 5; AppendTag(f.tags, "choch"); }
   if(f.engulfing)         { f.score += 4; AppendTag(f.tags, "engulfing"); }
   if(f.pinbar)            { f.score += 3; AppendTag(f.tags, "pinbar"); }
   if(f.rejection)         { f.score += 2; AppendTag(f.tags, "rejection"); }

   f.score = ClampInt(f.score, 0, 15);
   if(f.tags == "")
      f.tags = "basic";
   return f;
}

bool FindActiveFvg(const Direction dir, double &zoneLow, double &zoneHigh)
{
   double price = CurrentEntryPrice(dir);
   double atr = BufferValue(hAtrSetup, 0, 1);
   double buffer = atr * InpZoneAtrBuffer;

   for(int shift = 1; shift <= InpFvgLookback; ++shift)
   {
      double olderHigh = iHigh(TradeSymbol, InpSetupTf, shift + 2);
      double olderLow = iLow(TradeSymbol, InpSetupTf, shift + 2);
      double recentHigh = iHigh(TradeSymbol, InpSetupTf, shift);
      double recentLow = iLow(TradeSymbol, InpSetupTf, shift);

      if(dir == DIR_BUY && recentLow > olderHigh)
      {
         zoneLow = olderHigh;
         zoneHigh = recentLow;
         if(price >= zoneLow - buffer && price <= zoneHigh + buffer)
            return true;
      }
      else if(dir == DIR_SELL && recentHigh < olderLow)
      {
         zoneLow = recentHigh;
         zoneHigh = olderLow;
         if(price >= zoneLow - buffer && price <= zoneHigh + buffer)
            return true;
      }
   }

   zoneLow = 0.0;
   zoneHigh = 0.0;
   return false;
}

bool NearSupportResistance(const Direction dir, const ENUM_TIMEFRAMES tf)
{
   double atr = BufferValue(hAtrSetup, 0, 1);
   if(atr <= 0.0)
      return false;

   double price = CurrentEntryPrice(dir);
   double recentHigh = HighestHigh(tf, 2, InpStructureLookback * 2);
   double recentLow = LowestLow(tf, 2, InpStructureLookback * 2);
   double buffer = atr * 0.45;

   if(dir == DIR_BUY)
      return MathAbs(price - recentLow) <= buffer;
   if(dir == DIR_SELL)
      return MathAbs(price - recentHigh) <= buffer;

   return false;
}

bool IsPriceStretched(const Direction dir)
{
   double ema = BufferValue(hEmaFastSetup, 0, 1);
   double atr = BufferValue(hAtrSetup, 0, 1);
   if(atr <= 0.0)
      return false;
   double price = CurrentEntryPrice(dir);
   return MathAbs(price - ema) / atr >= 1.0;
}

double PullbackLimitPrice(const Direction dir,
                          const double emaFast,
                          const double atr)
{
   double offset = MathMax(0.0, atr * InpLimitEntryAtrOffset);
   if(dir == DIR_BUY)
      return NormalizePrice(emaFast - offset);
   if(dir == DIR_SELL)
      return NormalizePrice(emaFast + offset);
   return 0.0;
}

double BreakoutStopPrice(const Direction dir, const double atr)
{
   double offset = MathMax(PointValue(), atr * InpStopEntryAtrOffset);
   if(dir == DIR_BUY)
      return NormalizePrice(iHigh(TradeSymbol, InpTriggerTf, 1) + offset);
   if(dir == DIR_SELL)
      return NormalizePrice(iLow(TradeSymbol, InpTriggerTf, 1) - offset);
   return 0.0;
}

bool IsValidLimitPrice(const Direction dir, const double price)
{
   MqlTick tick;
   if(price <= 0.0 || !SymbolInfoTick(TradeSymbol, tick))
      return false;

   double minDistance = MinPendingDistance();
   if(dir == DIR_BUY)
      return price < tick.ask - minDistance;
   if(dir == DIR_SELL)
      return price > tick.bid + minDistance;
   return false;
}

bool IsValidStopPrice(const Direction dir, const double price)
{
   MqlTick tick;
   if(price <= 0.0 || !SymbolInfoTick(TradeSymbol, tick))
      return false;

   double minDistance = MinPendingDistance();
   if(dir == DIR_BUY)
      return price > tick.ask + minDistance;
   if(dir == DIR_SELL)
      return price < tick.bid - minDistance;
   return false;
}

bool BetterLimitThanMarket(const Direction dir, const double price)
{
   double current = CurrentEntryPrice(dir);
   if(current <= 0.0 || price <= 0.0)
      return false;
   if(dir == DIR_BUY)
      return price < current;
   if(dir == DIR_SELL)
      return price > current;
   return false;
}

bool BetterStopThanMarket(const Direction dir, const double price)
{
   double current = CurrentEntryPrice(dir);
   if(current <= 0.0 || price <= 0.0)
      return false;
   if(dir == DIR_BUY)
      return price > current;
   if(dir == DIR_SELL)
      return price < current;
   return false;
}

bool PendingPriceGuard(const TradeSignal &signal)
{
   if(signal.execution == EXEC_LIMIT && !IsValidLimitPrice(signal.direction, signal.orderPrice))
      return false;
   if(signal.execution == EXEC_STOP && !IsValidStopPrice(signal.direction, signal.orderPrice))
      return false;

   double atr = BufferValue(hAtrSetup, 0, 1);
   double current = CurrentEntryPrice(signal.direction);
   if(atr > 0.0 && MathAbs(signal.orderPrice - current) > atr * InpMaxPendingAtrDistance)
      return false;

   return true;
}

double MinPendingDistance()
{
   double point = PointValue();
   int stopLevel = (int)SymbolInfoInteger(TradeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   return MathMax(InpMinPendingDistancePoints * point, stopLevel * point);
}

double SignalEntryPrice(const TradeSignal &signal)
{
   if(signal.execution == EXEC_MARKET)
      return CurrentEntryPrice(signal.direction);
   return signal.orderPrice;
}

double NormalizePrice(const double price)
{
   return NormalizeDouble(price, DigitsForSymbol());
}

bool CompleteSignalPrices(TradeSignal &signal,
                          const double invalidation,
                          const double entryPrice)
{
   double entry = entryPrice;
   double atr = BufferValue(hAtrTrigger, 0, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   signal.idealEntry = entry;
   signal.orderPrice = entry;
   signal.invalidation = invalidation;

   double point = PointValue();
   int stopLevel = (int)SymbolInfoInteger(TradeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDistance = MathMax(stopLevel * point, point * 5.0);

   if(signal.direction == DIR_BUY)
   {
      signal.sl = invalidation - atr * InpAtrSlBuffer;
      if(entry - signal.sl < minStopDistance)
         signal.sl = entry - minStopDistance;
   }
   else if(signal.direction == DIR_SELL)
   {
      signal.sl = invalidation + atr * InpAtrSlBuffer;
      if(signal.sl - entry < minStopDistance)
         signal.sl = entry + minStopDistance;
   }
   else
      return false;

   double risk = MathAbs(entry - signal.sl);
   if(risk <= minStopDistance * 0.50)
      return false;

   double target = 0.0;
   if(!FindTargetPrice(signal.direction, entry, risk, target, signal.rr))
      return false;

   signal.tp = target;
   signal.sl = NormalizeDouble(signal.sl, DigitsForSymbol());
   signal.tp = NormalizeDouble(signal.tp, DigitsForSymbol());
   return true;
}

bool FindTargetPrice(const Direction dir,
                     const double entry,
                     const double risk,
                     double &target,
                     double &rr)
{
   double structural = 0.0;
   if(dir == DIR_BUY)
      structural = HighestHigh(InpSetupTf, 2, InpTargetLookback);
   else
      structural = LowestLow(InpSetupTf, 2, InpTargetLookback);

   bool hasRoom = false;
   if(dir == DIR_BUY && structural > entry)
   {
      rr = (structural - entry) / risk;
      hasRoom = rr >= InpMinExpectedRR;
   }
   else if(dir == DIR_SELL && structural < entry && structural > 0.0)
   {
      rr = (entry - structural) / risk;
      hasRoom = rr >= InpMinExpectedRR;
   }

   if(hasRoom)
   {
      target = structural;
      return true;
   }

   if(InpUseRoomToTargetFilter && InpSkipIfRoomTooSmall)
      return false;

   rr = InpDefaultRR;
   target = (dir == DIR_BUY) ? entry + risk * InpDefaultRR
                             : entry - risk * InpDefaultRR;
   return target > 0.0;
}

//+------------------------------------------------------------------+
//| Data helpers                                                      |
//+------------------------------------------------------------------+
bool IndicatorsReady()
{
   int handles[13] =
   {
      hEmaFastContext, hEmaSlowContext, hEmaFastSetup, hEmaSlowSetup,
      hEmaFastTrigger, hAtrContext, hAtrSetup, hAtrTrigger,
      hAdxContext, hAdxSetup, hRsiTrigger, hBandsContext, hBandsSetup
   };

   for(int i = 0; i < ArraySize(handles); ++i)
   {
      if(handles[i] == INVALID_HANDLE)
      {
         Print("Indicator handle failed at index ", i);
         return false;
      }
   }
   return true;
}

bool MarketDataReady()
{
   MqlTick tick;
   if(!SymbolInfoTick(TradeSymbol, tick))
      return false;

   int minBars = MathMax(InpEmaSlow + InpTargetLookback + 10, 120);
   if(Bars(TradeSymbol, InpContextTf) < minBars ||
      Bars(TradeSymbol, InpSetupTf) < minBars ||
      Bars(TradeSymbol, InpTriggerTf) < minBars)
      return false;

   return true;
}

double BufferValue(const int handle, const int buffer, const int shift)
{
   if(handle == INVALID_HANDLE)
      return 0.0;

   double values[];
   ArraySetAsSeries(values, true);
   if(CopyBuffer(handle, buffer, shift, 1, values) <= 0)
      return 0.0;
   return values[0];
}

double AverageBuffer(const int handle, const int buffer, const int startShift, const int count)
{
   if(handle == INVALID_HANDLE || count <= 0)
      return 0.0;

   double values[];
   ArraySetAsSeries(values, true);
   int copied = CopyBuffer(handle, buffer, startShift, count, values);
   if(copied <= 0)
      return 0.0;

   double sum = 0.0;
   int usable = 0;
   for(int i = 0; i < copied; ++i)
   {
      if(values[i] > 0.0)
      {
         sum += values[i];
         usable++;
      }
   }

   return usable > 0 ? sum / usable : 0.0;
}

double HighestHigh(const ENUM_TIMEFRAMES tf, const int startShift, const int count)
{
   double result = -1.0;
   for(int i = startShift; i < startShift + count; ++i)
   {
      double v = iHigh(TradeSymbol, tf, i);
      if(v > result)
         result = v;
   }
   return result > 0.0 ? result : 0.0;
}

double LowestLow(const ENUM_TIMEFRAMES tf, const int startShift, const int count)
{
   double result = 1.0e100;
   for(int i = startShift; i < startShift + count; ++i)
   {
      double v = iLow(TradeSymbol, tf, i);
      if(v > 0.0 && v < result)
         result = v;
   }
   return result < 1.0e99 ? result : 0.0;
}

double CurrentEntryPrice(const Direction dir)
{
   MqlTick tick;
   if(!SymbolInfoTick(TradeSymbol, tick))
      return 0.0;
   if(dir == DIR_BUY)
      return tick.ask;
   if(dir == DIR_SELL)
      return tick.bid;
   return (tick.ask + tick.bid) * 0.5;
}

double SpreadPoints()
{
   MqlTick tick;
   if(!SymbolInfoTick(TradeSymbol, tick))
      return 999999.0;
   return (tick.ask - tick.bid) / PointValue();
}

double PointValue()
{
   double p = SymbolInfoDouble(TradeSymbol, SYMBOL_POINT);
   return p > 0.0 ? p : _Point;
}

int DigitsForSymbol()
{
   return (int)SymbolInfoInteger(TradeSymbol, SYMBOL_DIGITS);
}

void ReleaseHandle(int &handle)
{
   if(handle != INVALID_HANDLE)
   {
      IndicatorRelease(handle);
      handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Account, volume, and history helpers                              |
//+------------------------------------------------------------------+
void UpdatePeakEquity()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > g_peakEquity)
   {
      g_peakEquity = equity;
      GlobalVariableSet(GvKey("PeakEquity"), g_peakEquity);
   }
}

double CurrentDrawdownPct()
{
   if(g_peakEquity <= 0.0)
      return 0.0;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   return MathMax(0.0, (g_peakEquity - equity) / g_peakEquity * 100.0);
}

double MarginUsagePct()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   if(equity <= 0.0)
      return 0.0;
   return margin / equity * 100.0;
}

double MoneyRiskPerLot(const double stopDistance)
{
   double tickValue = SymbolInfoDouble(TradeSymbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(TradeSymbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0 || stopDistance <= 0.0)
      return 0.0;
   return stopDistance / tickSize * tickValue;
}

double ScoreLotModifier(const int score)
{
   if(score <= 76) return 0.50;
   if(score <= 82) return 0.75;
   if(score <= 89) return 1.00;
   return 1.10;
}

double DrawdownLotModifier()
{
   double dd = CurrentDrawdownPct();
   if(dd < 3.0) return 1.00;
   if(dd < 6.0) return 0.80;
   if(dd < 10.0) return 0.50;
   if(dd < 15.0) return 0.25;
   return 0.0;
}

double VolatilityLotModifier()
{
   double atr = BufferValue(hAtrContext, 0, 1);
   double atrAvg = AverageBuffer(hAtrContext, 0, 2, 50);
   if(atr <= 0.0 || atrAvg <= 0.0)
      return 1.0;
   double ratio = atr / atrAvg;
   if(ratio >= 2.20) return 0.40;
   if(ratio >= 1.60) return 0.70;
   if(ratio <= 0.60) return 0.85;
   return 1.0;
}

double ExposureLotModifier()
{
   BasketInfo buyBasket;
   BasketInfo sellBasket;
   BuildBasket(DIR_BUY, buyBasket);
   BuildBasket(DIR_SELL, sellBasket);
   double exposure = buyBasket.lots + sellBasket.lots;
   if(InpMaxTotalLot <= 0.0)
      return 1.0;
   double ratio = exposure / InpMaxTotalLot;
   if(ratio >= 0.75) return 0.30;
   if(ratio >= 0.50) return 0.60;
   if(ratio >= 0.25) return 0.85;
   return 1.0;
}

double NormalizeVolume(const double volume)
{
   double minLot = MathMax(MinBrokerLot(), InpMinLot);
   double maxLot = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = 0.01;

   double v = MathMin(volume, maxLot);
   v = MathFloor(v / step + 1.0e-8) * step;
   v = NormalizeDouble(v, VolumeDigits(step));
   if(v < minLot)
      return 0.0;
   return v;
}

double MinBrokerLot()
{
   double minLot = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_MIN);
   return minLot > 0.0 ? minLot : 0.01;
}

int VolumeDigits(const double step)
{
   if(step >= 1.0) return 0;
   if(step >= 0.1) return 1;
   if(step >= 0.01) return 2;
   if(step >= 0.001) return 3;
   return 4;
}

int TradesLastHour()
{
   datetime to = TimeCurrent();
   datetime from = to - 3600;
   if(!HistorySelect(from, to))
      return 0;

   int count = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != TradeSymbol)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != (long)InpMagicNumber)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         count++;
   }
   return count;
}

int ConsecutiveLosses()
{
   datetime to = TimeCurrent();
   datetime from = to - 86400 * 30;
   if(!HistorySelect(from, to))
      return 0;

   int losses = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != TradeSymbol)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != (long)InpMagicNumber)
         continue;

      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT)
         continue;

      double pnl = HistoryDealGetDouble(deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(deal, DEAL_SWAP)
                 + HistoryDealGetDouble(deal, DEAL_COMMISSION);
      if(pnl < 0.0)
         losses++;
      else if(pnl > 0.0)
         break;
   }
   return losses;
}

int CountOwnedPendingOrders(const Direction dir)
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) != TradeSymbol)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber)
         continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!IsPendingOrderType(type))
         continue;

      if(dir == DIR_NONE || PendingOrderDirection(type) == dir)
         count++;
   }
   return count;
}

double PendingOrderLots(const Direction dir)
{
   double lots = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) != TradeSymbol)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber)
         continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!IsPendingOrderType(type))
         continue;

      if(dir == DIR_NONE || PendingOrderDirection(type) == dir)
         lots += OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   return lots;
}

bool HasNearPendingOrder(const TradeSignal &signal)
{
   double atr = BufferValue(hAtrSetup, 0, 1);
   double duplicateDistance = MathMax(MinPendingDistance(), atr * 0.25);

   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) != TradeSymbol)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber)
         continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!IsPendingOrderType(type))
         continue;
      if(PendingOrderDirection(type) != signal.direction)
         continue;

      double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      if(MathAbs(orderPrice - signal.orderPrice) <= duplicateDistance)
         return true;
   }

   return false;
}

bool IsPendingOrderType(const ENUM_ORDER_TYPE type)
{
   return type == ORDER_TYPE_BUY_LIMIT ||
          type == ORDER_TYPE_SELL_LIMIT ||
          type == ORDER_TYPE_BUY_STOP ||
          type == ORDER_TYPE_SELL_STOP ||
          type == ORDER_TYPE_BUY_STOP_LIMIT ||
          type == ORDER_TYPE_SELL_STOP_LIMIT;
}

Direction PendingOrderDirection(const ENUM_ORDER_TYPE type)
{
   if(type == ORDER_TYPE_BUY_LIMIT ||
      type == ORDER_TYPE_BUY_STOP ||
      type == ORDER_TYPE_BUY_STOP_LIMIT)
      return DIR_BUY;
   if(type == ORDER_TYPE_SELL_LIMIT ||
      type == ORDER_TYPE_SELL_STOP ||
      type == ORDER_TYPE_SELL_STOP_LIMIT)
      return DIR_SELL;
   return DIR_NONE;
}

//+------------------------------------------------------------------+
//| Session and string helpers                                        |
//+------------------------------------------------------------------+
bool IsInAllowedSession()
{
   MqlDateTime t;
   TimeToStruct(TimeGMT(), t);
   int hour = t.hour;

   bool anyConfigured = InpTradeAsian || InpTradeLondon || InpTradeNewYork ||
                        (InpCustomSessionStartGmt >= 0 && InpCustomSessionEndGmt >= 0);
   if(!anyConfigured)
      return true;

   bool allowed = false;
   if(InpTradeAsian && hour >= 0 && hour < 8)
      allowed = true;
   if(InpTradeLondon && hour >= 7 && hour < 16)
      allowed = true;
   if(InpTradeNewYork && hour >= 12 && hour < 21)
      allowed = true;
   if(InpCustomSessionStartGmt >= 0 && InpCustomSessionEndGmt >= 0)
      allowed = allowed || IsHourInRange(hour, InpCustomSessionStartGmt, InpCustomSessionEndGmt);

   return allowed;
}

bool IsHourInRange(const int hour, const int startHour, const int endHour)
{
   int start = ((startHour % 24) + 24) % 24;
   int end = ((endHour % 24) + 24) % 24;
   if(start == end)
      return true;
   if(start < end)
      return hour >= start && hour < end;
   return hour >= start || hour < end;
}

bool IsStrongOpposite(const Direction dir, const MarketRegime regime)
{
   if(dir == DIR_BUY)
      return regime == REGIME_STRONG_DOWNTREND || regime == REGIME_CHAOTIC;
   if(dir == DIR_SELL)
      return regime == REGIME_STRONG_UPTREND || regime == REGIME_CHAOTIC;
   return true;
}

Direction OppositeDirection(const Direction dir)
{
   if(dir == DIR_BUY) return DIR_SELL;
   if(dir == DIR_SELL) return DIR_BUY;
   return DIR_NONE;
}

TradeSignal EmptySignal()
{
   TradeSignal s;
   s.valid = false;
   s.direction = DIR_NONE;
   s.strategy = "";
   s.score = 0;
   s.idealEntry = 0.0;
   s.orderPrice = 0.0;
   s.sl = 0.0;
   s.tp = 0.0;
   s.invalidation = 0.0;
   s.rr = 0.0;
   s.execution = EXEC_MARKET;
   s.contextScore = 0;
   s.structureScore = 0;
   s.setupScore = 0;
   s.locationScore = 0;
   s.paScore = 0;
   s.momentumScore = 0;
   s.volatilityScore = 0;
   s.spreadScore = 0;
   s.sessionScore = 0;
   s.reason = "";
   return s;
}

int ClampInt(const int value, const int minValue, const int maxValue)
{
   return MathMax(minValue, MathMin(maxValue, value));
}

void AppendTag(string &target, const string tag)
{
   if(target == "")
      target = tag;
   else
      target += "+" + tag;
}

string DirectionName(const Direction dir)
{
   if(dir == DIR_BUY) return "BUY";
   if(dir == DIR_SELL) return "SELL";
   return "NONE";
}

string RegimeName(const MarketRegime regime)
{
   switch(regime)
   {
      case REGIME_STRONG_UPTREND:   return "STRONG_UPTREND";
      case REGIME_UPTREND:          return "UPTREND";
      case REGIME_STRONG_DOWNTREND: return "STRONG_DOWNTREND";
      case REGIME_DOWNTREND:        return "DOWNTREND";
      case REGIME_RANGE:            return "RANGE";
      case REGIME_COMPRESSION:      return "COMPRESSION";
      case REGIME_BREAKOUT:         return "BREAKOUT";
      case REGIME_HIGH_VOLATILITY:  return "HIGH_VOLATILITY";
      case REGIME_CHAOTIC:          return "CHAOTIC";
      default:                      return "UNKNOWN";
   }
}

string StateName(const TradingState state)
{
   switch(state)
   {
      case STATE_RUNNING:       return "RUNNING";
      case STATE_NO_NEW_ENTRY:  return "NO_NEW_ENTRY";
      case STATE_RECOVERY_ONLY: return "RECOVERY_ONLY";
      case STATE_CLOSE_ONLY:    return "CLOSE_ONLY";
      case STATE_PAUSED:        return "PAUSED";
      case STATE_EMERGENCY:     return "EMERGENCY";
      default:                  return "UNKNOWN";
   }
}

string ExecutionName(const EntryExecution execution)
{
   switch(execution)
   {
      case EXEC_LIMIT:  return "LIMIT";
      case EXEC_STOP:   return "STOP";
      case EXEC_MARKET:
      default:          return "MARKET";
   }
}

string PendingTypeName(const ENUM_ORDER_TYPE type)
{
   switch(type)
   {
      case ORDER_TYPE_BUY_LIMIT:       return "BUY_LIMIT";
      case ORDER_TYPE_SELL_LIMIT:      return "SELL_LIMIT";
      case ORDER_TYPE_BUY_STOP:        return "BUY_STOP";
      case ORDER_TYPE_SELL_STOP:       return "SELL_STOP";
      case ORDER_TYPE_BUY_STOP_LIMIT:  return "BUY_STOP_LIMIT";
      case ORDER_TYPE_SELL_STOP_LIMIT: return "SELL_STOP_LIMIT";
      default:                         return "ORDER";
   }
}

string ShortStrategyName(const string strategy)
{
   if(strategy == "TPB") return "TPB";
   if(strategy == "SWP") return "SWP";
   if(strategy == "FVG") return "FVG";
   if(strategy == "BOR") return "BOR";
   if(strategy == "TrendPullback") return "TPB";
   if(strategy == "LiquiditySweep") return "SWP";
   if(strategy == "FVGRetracement") return "FVG";
   if(strategy == "BreakoutRetest") return "BOR";
   return "SIG";
}

string DealStrategyCode(const ulong deal)
{
   string comment = HistoryDealGetString(deal, DEAL_COMMENT);
   int first = StringFind(comment, "|");
   if(first < 0)
      return "";

   int second = StringFind(comment, "|", first + 1);
   if(second <= first)
      return "";

   string code = StringSubstr(comment, first + 1, second - first - 1);
   if(StrategyIdFromCode(code) <= 0)
      return "";
   return code;
}

int StrategyIdFromCode(const string code)
{
   if(code == "TPB") return 1;
   if(code == "SWP") return 2;
   if(code == "FVG") return 3;
   if(code == "BOR") return 4;
   return 0;
}

string StrategyCodeFromId(const int strategyId)
{
   if(strategyId == 1) return "TPB";
   if(strategyId == 2) return "SWP";
   if(strategyId == 3) return "FVG";
   if(strategyId == 4) return "BOR";
   return "";
}

string GvKey(const string name)
{
   return "Lambo_" + TradeSymbol + "_" + IntegerToString((long)InpMagicNumber) + "_" + name;
}

//+------------------------------------------------------------------+
//| Journal                                                           |
//+------------------------------------------------------------------+
void InitJournal()
{
   if(!InpWriteJournal)
      return;

   int handle = FileOpen(InpJournalFileName,
                         FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("Cannot open journal file: ", InpJournalFileName, " error=", GetLastError());
      return;
   }

   if(FileSize(handle) == 0)
   {
      FileWrite(handle, "timestamp", "action", "symbol", "direction", "strategy",
                "execution", "order_price", "context", "score", "entry", "sl", "tp", "lot", "rr",
                "spread_points", "pnl_or_code", "mae_money", "mfe_money",
                "equity", "drawdown_pct", "reason");
   }
   FileClose(handle);
}

void InitDailyAnalytics()
{
   if(!InpWriteDailyAnalysis)
      return;

   g_activeAnalysisDate = DateKey(TimeCurrent());
   InitDailyEventFile();
   InitDailySummaryFile();
}

void WriteJournal(const string action,
                  const string direction,
                  const string strategy,
                  const string context,
                  const int score,
                  const double entry,
                  const double sl,
                  const double tp,
                  const double lot,
                  const double rr,
                  const double spread,
                  const double pnlOrCode,
                  const string reason,
                  const string execution = "",
                  const double orderPrice = 0.0,
                  const double maeMoney = 0.0,
                  const double mfeMoney = 0.0)
{
   if(InpWriteJournal)
   {
      int handle = FileOpen(InpJournalFileName,
                            FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI);
      if(handle != INVALID_HANDLE)
      {
         FileSeek(handle, 0, SEEK_END);
         FileWrite(handle,
                   TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                   action,
                   TradeSymbol,
                   direction,
                   strategy,
                   execution,
                   DoubleToString(orderPrice, DigitsForSymbol()),
                   context,
                   score,
                   DoubleToString(entry, DigitsForSymbol()),
                   DoubleToString(sl, DigitsForSymbol()),
                   DoubleToString(tp, DigitsForSymbol()),
                   DoubleToString(lot, 2),
                   DoubleToString(rr, 2),
                   DoubleToString(spread, 1),
                   DoubleToString(pnlOrCode, 2),
                   DoubleToString(maeMoney, 2),
                   DoubleToString(mfeMoney, 2),
                   DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2),
                   DoubleToString(CurrentDrawdownPct(), 2),
                   reason);
         FileClose(handle);
      }
   }

   WriteDailyAnalysisEvent(action, direction, strategy, context, score, entry, sl, tp,
                           lot, rr, spread, pnlOrCode, reason, execution, orderPrice,
                           maeMoney, mfeMoney);
}

void InitDailyEventFile()
{
   int handle = FileOpen(InpDailyEventFileName,
                         FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("Cannot open daily event file: ", InpDailyEventFileName, " error=", GetLastError());
      return;
   }

   if(FileSize(handle) == 0)
   {
      FileWrite(handle, "date", "timestamp", "symbol", "action_group", "action",
                "direction", "strategy", "strategy_code", "execution", "context",
                "score", "score_bucket", "entry", "order_price", "sl", "tp",
                "lot", "rr", "spread_points", "pnl_or_code", "mae_money", "mfe_money",
                "equity", "drawdown_pct", "reason_key", "reason");
   }
   FileClose(handle);
}

void InitDailySummaryFile()
{
   int handle = FileOpen(InpDailySummaryFileName,
                         FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("Cannot open daily summary file: ", InpDailySummaryFileName, " error=", GetLastError());
      return;
   }

   if(FileSize(handle) == 0)
   {
      FileWrite(handle, "snapshot_time", "date", "symbol", "action_group",
                "strategy_code", "count", "avg_score", "total_pnl",
                "avg_mae", "avg_mfe", "source");
   }
   FileClose(handle);
}

void WriteDailyAnalysisEvent(const string action,
                             const string direction,
                             const string strategy,
                             const string context,
                             const int score,
                             const double entry,
                             const double sl,
                             const double tp,
                             const double lot,
                             const double rr,
                             const double spread,
                             const double pnlOrCode,
                             const string reason,
                             const string execution,
                             const double orderPrice,
                             const double maeMoney,
                             const double mfeMoney)
{
   if(!InpWriteDailyAnalysis)
      return;

   string actionGroup = JournalActionGroup(action);
   if(actionGroup == "")
      return;

   RollDailyAnalysisDay();
   AppendDailyEvent(action, actionGroup, direction, strategy, context, score,
                    entry, sl, tp, lot, rr, spread, pnlOrCode, reason,
                    execution, orderPrice, maeMoney, mfeMoney);
   UpdateDailyCounters(action, actionGroup, strategy, score, pnlOrCode,
                       maeMoney, mfeMoney);
}

void RollDailyAnalysisDay()
{
   string today = DateKey(TimeCurrent());
   if(g_activeAnalysisDate == "")
   {
      g_activeAnalysisDate = today;
      return;
   }

   if(today == g_activeAnalysisDate)
      return;

   FlushDailySummary(g_activeAnalysisDate, "day_roll");
   ClearDailyCounters(g_activeAnalysisDate);
   g_activeAnalysisDate = today;
}

void AppendDailyEvent(const string action,
                      const string actionGroup,
                      const string direction,
                      const string strategy,
                      const string context,
                      const int score,
                      const double entry,
                      const double sl,
                      const double tp,
                      const double lot,
                      const double rr,
                      const double spread,
                      const double pnlOrCode,
                      const string reason,
                      const string execution,
                      const double orderPrice,
                      const double maeMoney,
                      const double mfeMoney)
{
   int handle = FileOpen(InpDailyEventFileName,
                         FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return;

   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle,
             DateKey(TimeCurrent()),
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             TradeSymbol,
             actionGroup,
             action,
             direction,
             strategy,
             DailyStrategyCode(strategy),
             execution,
             context,
             score,
             ScoreBucket(score),
             DoubleToString(entry, DigitsForSymbol()),
             DoubleToString(orderPrice, DigitsForSymbol()),
             DoubleToString(sl, DigitsForSymbol()),
             DoubleToString(tp, DigitsForSymbol()),
             DoubleToString(lot, 2),
             DoubleToString(rr, 2),
             DoubleToString(spread, 1),
             DoubleToString(pnlOrCode, 2),
             DoubleToString(maeMoney, 2),
             DoubleToString(mfeMoney, 2),
             DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2),
             DoubleToString(CurrentDrawdownPct(), 2),
             ReasonKey(action, reason),
             reason);
   FileClose(handle);
}

void UpdateDailyCounters(const string action,
                         const string actionGroup,
                         const string strategy,
                         const int score,
                         const double pnlOrCode,
                         const double maeMoney,
                         const double mfeMoney)
{
   string actionCode = DailyActionCode(actionGroup);
   string strategyCode = DailyStrategyCode(strategy);
   string date = (g_activeAnalysisDate == "" ? DateKey(TimeCurrent()) : g_activeAnalysisDate);

   AddDailyMetric(date, actionCode, strategyCode, "C", 1.0);
   if(score > 0)
   {
      AddDailyMetric(date, actionCode, strategyCode, "SS", (double)score);
      AddDailyMetric(date, actionCode, strategyCode, "SC", 1.0);
   }

   if(action == "EXIT")
   {
      AddDailyMetric(date, actionCode, strategyCode, "PNL", pnlOrCode);
      AddDailyMetric(date, actionCode, strategyCode, "MAE", maeMoney);
      AddDailyMetric(date, actionCode, strategyCode, "MFE", mfeMoney);
      AddDailyMetric(date, actionCode, strategyCode, "EXC", 1.0);
   }
}

void FlushDailySummary(const string date, const string source)
{
   if(!InpWriteDailyAnalysis || date == "")
      return;

   int handle = FileOpen(InpDailySummaryFileName,
                         FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return;

   string actionCodes[7] = {"CAN", "REJ", "ENT", "FAIL", "EXT", "CLS", "CNP"};
   string strategyCodes[6] = {"TPB", "SWP", "FVG", "BOR", "SIG", "NA"};

   FileSeek(handle, 0, SEEK_END);
   for(int a = 0; a < ArraySize(actionCodes); ++a)
   {
      for(int s = 0; s < ArraySize(strategyCodes); ++s)
      {
         double count = DailyMetric(date, actionCodes[a], strategyCodes[s], "C");
         if(count <= 0.0)
            continue;

         double scoreCount = DailyMetric(date, actionCodes[a], strategyCodes[s], "SC");
         double avgScore = (scoreCount > 0.0 ?
                            DailyMetric(date, actionCodes[a], strategyCodes[s], "SS") / scoreCount : 0.0);
         double excursionCount = DailyMetric(date, actionCodes[a], strategyCodes[s], "EXC");
         double avgMae = (excursionCount > 0.0 ?
                          DailyMetric(date, actionCodes[a], strategyCodes[s], "MAE") / excursionCount : 0.0);
         double avgMfe = (excursionCount > 0.0 ?
                          DailyMetric(date, actionCodes[a], strategyCodes[s], "MFE") / excursionCount : 0.0);

         FileWrite(handle,
                   TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                   date,
                   TradeSymbol,
                   ActionGroupName(actionCodes[a]),
                   strategyCodes[s],
                   DoubleToString(count, 0),
                   DoubleToString(avgScore, 2),
                   DoubleToString(DailyMetric(date, actionCodes[a], strategyCodes[s], "PNL"), 2),
                   DoubleToString(avgMae, 2),
                   DoubleToString(avgMfe, 2),
                   source);
      }
   }

   FileClose(handle);
}

void ClearDailyCounters(const string date)
{
   string actionCodes[7] = {"CAN", "REJ", "ENT", "FAIL", "EXT", "CLS", "CNP"};
   string strategyCodes[6] = {"TPB", "SWP", "FVG", "BOR", "SIG", "NA"};
   string metrics[7] = {"C", "SS", "SC", "PNL", "MAE", "MFE", "EXC"};

   for(int a = 0; a < ArraySize(actionCodes); ++a)
   {
      for(int s = 0; s < ArraySize(strategyCodes); ++s)
      {
         for(int m = 0; m < ArraySize(metrics); ++m)
            GlobalVariableDel(DailyMetricKey(date, actionCodes[a], strategyCodes[s], metrics[m]));
      }
   }
}

void AddDailyMetric(const string date,
                    const string actionCode,
                    const string strategyCode,
                    const string metric,
                    const double delta)
{
   string key = DailyMetricKey(date, actionCode, strategyCode, metric);
   double value = 0.0;
   if(GlobalVariableCheck(key))
      value = GlobalVariableGet(key);
   GlobalVariableSet(key, value + delta);
}

double DailyMetric(const string date,
                   const string actionCode,
                   const string strategyCode,
                   const string metric)
{
   string key = DailyMetricKey(date, actionCode, strategyCode, metric);
   if(GlobalVariableCheck(key))
      return GlobalVariableGet(key);
   return 0.0;
}

string DailyMetricKey(const string date,
                      const string actionCode,
                      const string strategyCode,
                      const string metric)
{
   return GvKey("D" + DateToken(date) + "_" + actionCode + "_" + strategyCode + "_" + metric);
}

string JournalActionGroup(const string action)
{
   if(action == "CANDIDATE")
      return "CANDIDATE";
   if(StringFind(action, "REJECT_") == 0)
      return "REJECT";
   if(action == "ENTRY" || action == "ENTRY_RECOVERY" || action == "ENTRY_PYRAMID")
      return "ENTRY";
   if(action == "ORDER_FAILED")
      return "ORDER_FAILED";
   if(action == "EXIT")
      return "EXIT";
   if(action == "CLOSE_BASKET" || action == "CLOSE_ALL")
      return "CLOSE";
   if(StringFind(action, "CANCEL_PENDING") == 0)
      return "CANCEL_PENDING";
   return "";
}

string DailyActionCode(const string actionGroup)
{
   if(actionGroup == "CANDIDATE") return "CAN";
   if(actionGroup == "REJECT") return "REJ";
   if(actionGroup == "ENTRY") return "ENT";
   if(actionGroup == "ORDER_FAILED") return "FAIL";
   if(actionGroup == "EXIT") return "EXT";
   if(actionGroup == "CLOSE") return "CLS";
   if(actionGroup == "CANCEL_PENDING") return "CNP";
   return "UNK";
}

string ActionGroupName(const string actionCode)
{
   if(actionCode == "CAN") return "CANDIDATE";
   if(actionCode == "REJ") return "REJECT";
   if(actionCode == "ENT") return "ENTRY";
   if(actionCode == "FAIL") return "ORDER_FAILED";
   if(actionCode == "EXT") return "EXIT";
   if(actionCode == "CLS") return "CLOSE";
   if(actionCode == "CNP") return "CANCEL_PENDING";
   return "UNKNOWN";
}

string DailyStrategyCode(const string strategy)
{
   string code = ShortStrategyName(strategy);
   if(code == "SIG")
      return (strategy == "" ? "NA" : "SIG");
   return code;
}

string ScoreBucket(const int score)
{
   if(score <= 0) return "";
   if(score < 60) return "000_059";
   if(score < 65) return "060_064";
   if(score < 70) return "065_069";
   if(score < 75) return "070_074";
   if(score < 80) return "075_079";
   if(score < 85) return "080_084";
   if(score < 90) return "085_089";
   return "090_100";
}

string ReasonKey(const string action, const string reason)
{
   if(StringFind(action, "REJECT_") == 0)
      return action;
   if(action == "ORDER_FAILED")
      return "ORDER_FAILED";
   if(reason == "")
      return "";

   int split = StringFind(reason, ";");
   string key = (split >= 0 ? StringSubstr(reason, 0, split) : reason);
   if(StringLen(key) > 90)
      key = StringSubstr(key, 0, 90);
   return key;
}

string DateKey(const datetime when)
{
   return TimeToString(when, TIME_DATE);
}

string DateToken(const string date)
{
   string token = date;
   StringReplace(token, ".", "");
   StringReplace(token, "-", "");
   StringReplace(token, "/", "");
   return token;
}

string UlongToString(const ulong value)
{
   return StringFormat("%I64u", value);
}
