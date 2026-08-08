# Lamborghini EA

Prototype EA MQL5 cho XAUUSD, dùng M15 làm context, M5 làm setup và M2 làm trigger. Mục tiêu của bản này là dựng khung giao dịch bền: scoring thay vì AND cứng, risk supervisor đứng trên strategy, lot tính theo SL/risk, basket BUY và SELL độc lập, có journal để phục vụ backtest và tối ưu sau này.

> Không có cam kết win rate hay lợi nhuận. Chỉ chạy live sau khi đã backtest, demo-test và hiểu rõ rủi ro theo broker của bạn.

## Cấu trúc

```text
MQL5/Experts/LamborghiniEA.mq5  EA chính cho MetaTrader 5
docs/master-spec-v1.md          Tóm tắt logic thiết kế từ spec
docs/backtest-checklist.md      Checklist test và tối ưu
```

## Cài vào MT5

1. Mở MT5, vào `File > Open Data Folder`.
2. Copy file `MQL5/Experts/LamborghiniEA.mq5` vào thư mục `MQL5/Experts`.
3. Mở MetaEditor, compile `LamborghiniEA.mq5`.
4. Gắn EA vào chart XAUUSD, ưu tiên chart M2.
5. Bật `Algo Trading`.

Nếu broker dùng tên khác như `XAUUSDm`, đổi tham số `InpTradeSymbol`.

## Logic v1

EA tìm tín hiệu bằng 4 strategy độc lập:

- `TrendPullback`: trend/context đúng, M5 pullback vào EMA/location, M2 xác nhận.
- `LiquiditySweep`: sweep previous high/low, reclaim, CHoCH/rejection.
- `FVGRetracement`: giá quay lại FVG cùng hướng context, M2 xác nhận.
- `BreakoutRetest`: dùng trong range/compression, breakout rồi retest.

Mỗi candidate được chấm 0-100 theo:

- M15 direction/context
- Market structure
- Setup quality
- Location S/R, FVG, liquidity
- M2 price action
- Momentum
- ATR/volatility
- Spread
- Session

Hard filter chủ yếu nằm ở risk/safety: spread, drawdown, max lot, max basket risk, max trades/hour, margin usage, consecutive losses, price deviation và duplicate/chasing guard.

## Entry execution

EA hiện hỗ trợ 3 kiểu vào lệnh:

- `MARKET`: dùng cho Liquidity Sweep sau reclaim và các setup đã xác nhận mà giá còn hợp lệ.
- `LIMIT`: dùng cho Trend Pullback và FVG khi có giá pullback/retest tốt hơn giá hiện tại.
- `STOP`: dùng cho Breakout Retest khi cần đợi giá phá tiếp sau retest.

Các lệnh chờ có guard riêng:

- giới hạn tổng số pending order bằng `InpMaxPendingOrders`
- hết hạn theo số nến M2 bằng `InpPendingExpiryBars`
- kiểm tra khoảng cách tối thiểu bằng `InpMinPendingDistancePoints`
- hủy pending nếu regime đảo mạnh hoặc giá đi quá xa vùng dự kiến
- chống treo lệnh trùng gần cùng vùng giá

## Lot và risk

Mặc định `InpLotMode = LOT_SMART`.

Lot được tính theo:

```text
Risk based lot
* signal quality modifier
* drawdown modifier
* volatility modifier
* exposure modifier
```

SL được xác định trước lot. Recovery không dùng martingale mặc định; re-entry phải có setup mới và score cao hơn.

## Basket

EA quản lý BUY basket và SELL basket độc lập theo magic number:

- Basket trailing theo floating profit.
- Recovery chỉ được phép nếu score đạt ngưỡng cao hơn.
- Pyramiding dùng lot nhỏ dần.
- Invalidation có thể chặn re-entry; bật `InpCloseInvalidatedBasket` nếu muốn đóng basket khi thesis sai.
- Cross-basket net exit có thể đóng cả hai bên khi tổng net profit đủ.

## Journal

EA ghi file CSV:

```text
LamborghiniEA_journal.csv
```

File nằm trong thư mục MT5 common files khi `InpWriteJournal = true`. Journal ghi entry, reject reason, exit, score, SL/TP, lot, RR, spread, equity và drawdown.
Journal cũng ghi `execution` và `order_price` để phân tích Market/Limit/Stop trong backtest.

## Backtest gợi ý

Nên bắt đầu bằng Strategy Tester:

- Symbol: XAUUSD hoặc đúng symbol broker.
- Timeframe: M2.
- Model: Every tick based on real ticks nếu có.
- Date range: ít nhất 6-12 tháng, sau đó walk-forward.
- Lần đầu có thể dùng `LOT_FIXED` để xem logic vào lệnh, rồi chuyển `LOT_SMART`.

Các tham số nên optimize trước:

- `InpMinEntryScore`
- `InpMinRecoveryScore`
- `InpMaxEmaAtrDistance`
- `InpMinExpectedRR`
- `InpSkipIfRoomTooSmall`
- `InpMaxSpreadPoints`
- `InpRiskPerTradePct`
- `InpBasketTrailStartMoney`
- `InpBasketTrailGivebackMoney`

## Phase sau

Các phần sau chưa nằm trong prototype MQL5 này:

- Python learning engine.
- Shadow/candidate/live model promotion.
- AI vision second opinion.
- Stop-limit nâng cao và quản lý partial fill chi tiết.
- Smart trim chi tiết theo từng ticket.
- Database phục hồi nâng cao ngoài Global Variables và MT5 positions.

Prototype này ưu tiên có một EA chạy được, có risk supervisor và có journal để lấy dữ liệu thật trước khi làm các tầng học/tối ưu.
