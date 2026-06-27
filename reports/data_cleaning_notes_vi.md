# Ghi chú làm sạch dữ liệu - Project 1

Nguồn dữ liệu là `wage.xlsx`, gồm 3010 quan sát và 34 biến. Sau bước làm sạch, nhóm có hai bộ dữ liệu đầu ra:

- `data/processed/wage_eda.csv`: dùng cho thống kê mô tả và trực quan hóa. Bộ này giữ missing value để khi thống kê có thể báo cáo số quan sát hợp lệ theo từng biến.
- `data/processed/wage_model.csv`: dùng cho OLS và Machine Learning. Bộ này đã xử lý missing, mã hóa biến phân loại và loại các biến có nguy cơ gây sai mô hình.

## Các quyết định chính

- Loại `id` vì đây chỉ là mã quan sát.
- Giữ `wage` trong file EDA để mô tả dữ liệu, nhưng không đưa vào mô hình dự báo `lwage` vì `lwage = log(wage)`.
- Kiểm tra `lwage` với `log(wage)`: sai số tối đa rất nhỏ, khoảng `7.13e-07`, nên có thể xem `lwage` là log của `wage`.
- Kiểm tra `expersq`: không có dòng nào sai so với `exper^2`.
- Với file modeling, điền missing bằng median cho `IQ`, `KWW`, `fatheduc`, `motheduc`.
- Với `married` và `libcrd14`, điền missing bằng mode vì số dòng thiếu rất ít.
- Tạo thêm biến đánh dấu missing cho các biến đã impute: `IQ_missing`, `KWW_missing`, `fatheduc_missing`, `motheduc_missing`, `married_missing`, `libcrd14_missing`.
- Xử lý `married` như biến phân loại, mã hóa thành các biến giả `married_2` đến `married_6`, lấy nhóm `married_1` làm nhóm gốc.
- Loại `reg661` khỏi file modeling để làm nhóm vùng gốc, tránh đa cộng tuyến hoàn hảo khi hồi quy có intercept.
- Không xóa outlier trước khi thống kê; chỉ báo cáo số lượng outlier theo quy tắc IQR.

## Missing value đáng chú ý

- `IQ`: thiếu 949 dòng, chiếm 31.53%; điền median = 103 trong file modeling.
- `fatheduc`: thiếu 690 dòng, chiếm 22.92%; điền median = 10.
- `motheduc`: thiếu 353 dòng, chiếm 11.73%; điền median = 12.
- `KWW`: thiếu 47 dòng, chiếm 1.56%; điền median = 34.
- `libcrd14`: thiếu 13 dòng, chiếm 0.43%; điền mode = 1.
- `married`: thiếu 7 dòng, chiếm 0.23%; điền mode = 1.

## Outlier theo IQR

- `wage`: 83 outlier, chiếm 2.76%.
- `exper`: 50 outlier, chiếm 1.66%.
- `lwage`: 38 outlier, chiếm 1.26%.
- `IQ`: 21 outlier, chiếm 1.02%.
- `educ`: 19 outlier, chiếm 0.63%.
- `KWW`: 9 outlier, chiếm 0.30%.

Vì biến mục tiêu của dự án là `lwage`, tác động của outlier tiền lương đã được giảm đáng kể so với `wage`. Do đó, ở bước ban đầu nhóm nên giữ outlier và chỉ xem xét winsorize trong phân tích nhạy cảm nếu cần.
