# Backtest Checklist

## 1. Kiểm tra EA có trade không

Mục tiêu đầu tiên chưa phải profit, mà là xem bot có quá chặt không.

Theo dõi trong journal:

- `REJECT_SCORE`
- `REJECT_SPREAD`
- `REJECT_CHASE`
- `REJECT_SPACING`
- `REJECT_STATE`
- `REJECT_PENDING_LIMIT`
- `REJECT_PENDING_PRICE`
- `REJECT_DUP_PENDING`
- `CANCEL_PENDING`
- `ENTRY`
- `ENTRY_RECOVERY`
- `ENTRY_PYRAMID`

Nếu 1-2 tháng không có lệnh, thử:

- giảm `InpMinEntryScore` từ 75 xuống 70
- đặt `InpSkipIfRoomTooSmall = false`
- tăng nhẹ `InpMaxEntryAtrDeviation`
- tăng `InpMaxSpreadPoints` theo spread thực tế của broker
- nếu pending quá ít khớp, giảm `InpMinPendingDistancePoints` hoặc tăng `InpPendingExpiryBars`

## 2. Test logic trước khi test lot

Chạy `InpLotMode = LOT_FIXED` và lot nhỏ để đánh giá:

- số candidate được nhận
- strategy nào tạo nhiều lệnh
- score bucket nào có edge
- session nào hoạt động tốt
- drawdown đến từ strategy nào

Sau đó mới chuyển sang `LOT_SMART`.

## 3. Optimize thô

Optimize theo cụm nhỏ, tránh overfit:

- score threshold: 68-85
- EMA distance: 0.9-1.8 ATR
- minimum RR: 1.2-2.2
- ATR SL buffer: 0.2-0.7
- pending expiry bars: 1-6
- pending min distance theo spread/stop-level broker
- basket trailing start/giveback

Không optimize quá nhiều tham số cùng lúc.

## 4. Walk-forward

Ví dụ:

- Train: 3 tháng
- Test: 1 tháng
- Lặp qua nhiều giai đoạn thị trường

Một config tốt phải không sụp trên giai đoạn out-of-sample.

## 5. Tiêu chí loại

Loại config nếu:

- drawdown vượt giới hạn
- profit factor dưới 1.3
- quá ít lệnh, ví dụ dưới 1 basket/ngày trung bình
- lợi nhuận đến từ một lệnh bất thường
- recovery tạo exposure quá lớn
- spread/slippage thực tế làm mất edge

## 6. Demo trước live

Chạy demo ít nhất vài tuần:

- cùng broker
- cùng symbol suffix
- cùng spread/commission
- cùng VPS hoặc máy chạy thật

Chỉ tăng risk sau khi journal demo khớp kỳ vọng backtest.
