# Ghi chú xử lý dữ liệu - Wage Project

## Mục tiêu phân tích

Mục tiêu của project là phân tích các yếu tố ảnh hưởng đến log tiền lương (`lwage`).

- Biến mục tiêu: `lwage`
- Biến đầu vào chính: `educ`, `exper`, `expersq`, `IQ`, `KWW`, `black`, `married`, `south`, `smsa`, `fatheduc`, `motheduc`, các biến vùng và biến gia đình.

## Dữ liệu gốc

- File gốc: `data/wage.xlsx`
- Số dòng: 3010
- Số cột: 34
- Một số biến quan trọng: lwage, wage, educ, exper, expersq, IQ, KWW, black, married, south, smsa, fatheduc, motheduc

## Thống kê dữ liệu gốc

| variable | count | mean | std | min | median | max |
| --- | --- | --- | --- | --- | --- | --- |
| lwage | 3010.0000 | 6.2618 | 0.4438 | 4.6052 | 6.2869 | 7.7849 |
| wage | 3010.0000 | 577.2824 | 262.9583 | 100.0000 | 537.5000 | 2404.0000 |
| educ | 3010.0000 | 13.2635 | 2.6769 | 1.0000 | 13.0000 | 18.0000 |
| exper | 3010.0000 | 8.8561 | 4.1417 | 0.0000 | 8.0000 | 23.0000 |
| expersq | 3010.0000 | 95.5791 | 84.6183 | 0.0000 | 64.0000 | 529.0000 |
| IQ | 2061.0000 | 102.4498 | 15.4238 | 50.0000 | 103.0000 | 149.0000 |
| KWW | 2963.0000 | 33.5407 | 8.6116 | 4.0000 | 34.0000 | 56.0000 |
| black | 3010.0000 | 0.2336 | 0.4232 | 0.0000 | 0.0000 | 1.0000 |
| married | 3003.0000 | 2.2714 | 2.0668 | 1.0000 | 1.0000 | 6.0000 |
| south | 3010.0000 | 0.4037 | 0.4907 | 0.0000 | 0.0000 | 1.0000 |
| smsa | 3010.0000 | 0.7130 | 0.4525 | 0.0000 | 1.0000 | 1.0000 |
| fatheduc | 2320.0000 | 10.0034 | 3.7207 | 0.0000 | 10.0000 | 18.0000 |
| motheduc | 2657.0000 | 10.3481 | 3.1797 | 0.0000 | 12.0000 | 18.0000 |

## Missing value trong dữ liệu gốc

| variable | missing_count | missing_pct |
| --- | --- | --- |
| IQ | 949 | 31.53% |
| KWW | 47 | 1.56% |
| married | 7 | 0.23% |
| fatheduc | 690 | 22.92% |
| motheduc | 353 | 11.73% |

## Cách tạo dữ liệu phân tích

Từ dữ liệu gốc, project tạo 2 file CSV:

| file | purpose |
| --- | --- |
| data/wage.xlsx | Dữ liệu gốc dùng để truy vết và mô tả dữ liệu ban đầu. |
| data/wage_eda.csv | Dữ liệu phục vụ EDA; giữ `wage`, `lwage`, biến gốc và missing value để thống kê/phân phối phản ánh dữ liệu thật. |
| data/wage_model.csv | Dữ liệu phục vụ mô hình; chỉ giữ biến số, xử lý missing, tạo biến giả cho `married`, bỏ `wage` để tránh rò rỉ khi dự đoán `lwage`. |

## Xử lý chính

- `wage_eda.csv`: giữ dữ liệu gần với bản gốc để phục vụ thống kê mô tả, histogram, boxplot, scatter plot và heatmap.
- `wage_model.csv`: loại `wage` khỏi biến đầu vào vì `wage` là nguồn trực tiếp tạo ra `lwage`; nếu dùng `wage` để dự đoán `lwage` sẽ gây rò rỉ dữ liệu.
- Các biến thiếu quan trọng như `IQ`, `KWW`, `fatheduc`, `motheduc` được điền bằng median trong file model.
- `married` được one-hot encoding thành `married_2` đến `married_6`; nhóm `married_1` là baseline.
- Các biến vùng `reg662` đến `reg669` được giữ; `reg661` là baseline.
- Thêm các biến cờ missing như `IQ_missing`, `fatheduc_missing` để mô hình vẫn biết quan sát nào từng bị thiếu dữ liệu.

## Kích thước dữ liệu sau xử lý

- `wage_eda.csv`: 3010 dòng x 30 cột.
- `wage_model.csv`: 3010 dòng x 38 cột.


