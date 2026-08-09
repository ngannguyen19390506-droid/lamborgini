# Journal Analysis

EA ghi 3 file CSV trong MT5 common files.

## 1. LamborghiniEA_journal.csv

File chính để audit từng quyết định.

Cột quan trọng:

- `action`: `CANDIDATE`, `REJECT_*`, `ENTRY`, `ENTRY_RECOVERY`, `ENTRY_PYRAMID`, `ORDER_FAILED`, `EXIT`.
- `execution`: `MARKET`, `LIMIT`, `STOP`.
- `order_price`: giá pending dự kiến, hữu ích khi xem lệnh chờ có bị đặt quá xa không.
- `score`: tổng điểm của setup.
- `reason`: giải thích đầy đủ, gồm `scores=ctx,str,set,loc,pa,mom,vol,spr,ses,total`.
- `mae_money`: mức âm nổi lớn nhất của position trước khi đóng.
- `mfe_money`: mức lời nổi lớn nhất của position trước khi đóng.

MAE/MFE chỉ có ý nghĩa trên dòng `EXIT`. Ví dụ:

- Dòng `EXIT` cố gắng giữ lại `strategy` gốc bằng code `TPB`, `SWP`, `FVG`, `BOR` từ comment của lệnh mở.
- MAE âm sâu nhưng MFE thấp: entry/SL có thể chưa tốt, hoặc setup thiếu follow-through.
- MFE cao nhưng profit thấp/âm: trailing, BE hoặc TP có thể trả lại quá nhiều.
- MAE rất nhỏ, MFE tốt: có thể cân nhắc trailing/scale-out tinh hơn thay vì nới SL.

## 2. LamborghiniEA_daily_events.csv

File này phục vụ phân tích candidate/reject theo ngày. Mỗi dòng là một sự kiện đã được chuẩn hóa.

Cột nên lọc/pivot:

- `date`
- `action_group`: `CANDIDATE`, `REJECT`, `ENTRY`, `EXIT`, `ORDER_FAILED`, `CANCEL_PENDING`, `CLOSE`.
- `action`: reject cụ thể như `REJECT_SCORE`, `REJECT_CHASE`, `REJECT_PENDING_PRICE`.
- `strategy_code`: `TPB`, `SWP`, `FVG`, `BOR`, `NA`.
- `score_bucket`: nhóm điểm, ví dụ `070_074`, `075_079`, `080_084`.
- `reason_key`: lý do ngắn để gom reject/candidate.

Cách đọc nhanh:

- Nhiều `CANDIDATE`, ít `ENTRY`, nhiều `REJECT_SCORE`: ngưỡng score đang chặt.
- Nhiều `REJECT_CHASE`: tín hiệu đúng nhưng giá đã chạy xa, nên ưu tiên pending/entry offset.
- Nhiều `REJECT_PENDING_PRICE`: pending đặt quá gần stop-level/spread hoặc quá xa vùng hợp lệ.
- Nhiều `REJECT_SPREAD`: broker/session spread không phù hợp với cấu hình hiện tại.
- Nhiều `CANDIDATE` score thấp ở cùng strategy: nên siết component gate, không chỉ tăng score tổng.

## 3. LamborghiniEA_daily_summary.csv

File này ghi snapshot tổng hợp theo ngày, action group và strategy.

Cột chính:

- `date`
- `action_group`
- `strategy_code`
- `count`
- `avg_score`
- `total_pnl`
- `avg_mae`
- `avg_mfe`
- `source`: `day_roll` hoặc `deinit`

Nếu có nhiều snapshot cùng `date/action_group/strategy_code`, dùng dòng mới nhất theo `snapshot_time`.

Checklist sau mỗi backtest:

1. Xem `daily_summary`: trung bình mỗi ngày có bao nhiêu `CANDIDATE`, `REJECT`, `ENTRY`.
2. Xem `daily_events`: reject nào chiếm nhiều nhất.
3. So sánh `score_bucket` với kết quả `EXIT`.
4. So sánh `avg_mae` và `avg_mfe` theo strategy.
5. Chỉ nới điều kiện bị nghẽn thật sự, không hạ toàn bộ filter.
