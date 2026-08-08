# Lamborghini Master Spec v1

## Mục tiêu

- Symbol chính: XAUUSD.
- Timeframe: M15 context, M5 setup, M2 trigger.
- Ưu tiên win rate, profit factor và drawdown bền hơn số lượng lệnh.
- Không tối ưu riêng win rate. Một cấu hình thắng cao nhưng drawdown lớn hoặc quá ít lệnh phải bị loại.

## Thứ tự quyền hạn

```text
Risk
Execution safety
Strategy
Recovery
AI
```

Risk supervisor luôn có quyền từ chối lệnh, dù strategy score cao.

## Regime

EA phân loại thị trường:

- `STRONG_UPTREND`
- `UPTREND`
- `STRONG_DOWNTREND`
- `DOWNTREND`
- `RANGE`
- `COMPRESSION`
- `BREAKOUT`
- `HIGH_VOLATILITY`
- `CHAOTIC`

Regime được ước lượng bằng EMA gap/slope, ATR ratio, ADX, Bollinger width và structure.

## Strategy chính

Strategy hoạt động độc lập, không bắt tất cả cùng đúng:

- Trend Pullback
- Liquidity Sweep
- FVG Retracement
- Breakout Retest

Một setup đủ score có thể trade, miễn risk và execution guard cho phép.

## Entry

Luồng entry:

```text
Direction
Entry zone
M2 trigger
SL/invalidation
Risk lot
Execution guard
Order
```

Bot không BUY/SELL chỉ vì EMA cùng hướng. Giá phải ở vùng đáng vào, có trigger, có SL rõ ràng và không bị chase.

## Scoring

Tín hiệu được chấm 0-100:

- M15 direction/context: 15
- Market structure: 15
- Setup quality: 15
- Location: 15
- M2 price action: 15
- Momentum: 10
- ATR/volatility: 5
- Spread: 5
- Session: 5

Ngưỡng ban đầu trong EA là `InpMinEntryScore = 75`, cần backtest để hiệu chỉnh.

## Recovery và pyramiding

- Không dùng DCA step âm tiền cố định.
- Re-entry chỉ mở khi có setup mới, đủ spacing ATR, trend/thesis chưa invalid và score cao hơn.
- Recovery lot mặc định không tăng kiểu martingale.
- Pyramiding chỉ khi basket đang lời, setup mới đủ tốt, lot nhỏ dần.

## Basket

BUY basket và SELL basket độc lập, cùng magic number:

- avg price
- total lot
- floating P/L
- position count
- trailing protected profit
- invalidation state

EA rebuild basket từ MT5 positions sau mỗi tick, nên restart không mất vị thế đang mở.

## Journal

Từ v1 phải ghi dữ liệu trade/reject để backtest và học:

- timestamp
- direction
- strategy
- regime/context
- entry score
- entry/SL/TP
- lot
- RR
- spread
- equity/drawdown
- reason

## KPI backtest

Không chọn bản chỉ vì win rate. Cần xem:

- Basket win rate
- Profit factor
- Expectancy
- Max drawdown
- Recovery factor
- Consecutive losses
- Baskets/day
- MAE/MFE
- Exposure

Mốc ban đầu mong muốn:

- Basket win rate khoảng 70%+ nếu dữ liệu chứng minh.
- Profit factor từ 1.5, ưu tiên 1.8+.
- Max DD cố gắng dưới 15-20%.
- Trung bình khoảng 2-5 basket/ngày, không ép ngày nào cũng có lệnh.
