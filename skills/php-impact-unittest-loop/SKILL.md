---
name: php-impact-unittest-loop
description: 'Phân tích vùng ảnh hưởng, tự động tạo test case PHPUnit và chạy lặp để đạt 90% coverage cho mã nguồn PHP.'
---

# PHP Impact Unittest Loop

Sử dụng skill này sau khi đã hoàn tất thay đổi mã nguồn PHP và người dùng yêu cầu kiểm tra lại (retest), đánh giá ảnh hưởng (impact), hoặc nâng cao độ phủ (coverage).

**Lưu ý giới hạn của PHPUnit**: PHPUnit không có bộ lọc (filter) tích hợp sẵn để chỉ chạy hoặc báo cáo coverage cho các hàm vừa bị thay đổi. Việc lấy coverage yêu cầu cài đặt extension `Xdebug` (với `XDEBUG_MODE=coverage`) hoặc `pcov`.

## 1. Phân tích vùng ảnh hưởng (Impact)

Sử dụng `git status` hoặc `git diff -U0` để phân loại các file mã nguồn đã thay đổi và map chính xác thay đổi tới các function/method cụ thể trong PHP.
Nếu không có công cụ tự động, phân tích thủ công theo thứ tự đọc các lớp (Layer): `Controller -> Service -> Repository -> Model`.
Lập bảng đánh giá mức độ ảnh hưởng: File / Hàm / API tương ứng / Mức độ rủi ro (HIGH/MED/LOW).

## 2. Xác định mục tiêu cần kiểm tra (Target)

Chỉ định các hàm, API cụ thể cần viết test dựa trên quy tắc sau:
- Bao gồm các hàm bị thay đổi trực tiếp (map từ `git diff`).
- Bao gồm các hàm gọi đến (callers) hoặc được gọi từ (callees) hàm thay đổi với khoảng cách 1 hop.
- Bao gồm các API handler liên quan trực tiếp đến luồng logic thay đổi.
- Loại trừ các đoạn mã được sinh tự động (generated code) hoặc các lớp cấu hình hệ thống (config).

## 3. Tạo bài kiểm tra (Tạo test)

Viết các bài kiểm tra bằng PHPUnit.
Đặt file test tại thư mục `tests` với cấu trúc thư mục phản chiếu chính xác thư mục `src` (hoặc thư mục mã nguồn chính). Tên file test phải có hậu tố `Test`.
Giả lập (mock) các đường ranh giới hệ thống (Database, HTTP client) bằng `createMock()` hoặc `MockBuilder`.
Mỗi nhánh logic (branch) bị thay đổi phải có ít nhất một test case tương ứng:
- Đường dẫn chuẩn (happy path)
- Giá trị null
- Dữ liệu trống (empty)
- Bắn lỗi (exception)
- Quyền truy cập (permission)

## 4. Chạy kiểm tra chọn lọc (Chạy selective)

Thực thi test riêng lẻ trên các file vừa tạo hoặc thay đổi, **cấm** chạy toàn bộ test suite trừ khi vùng ảnh hưởng lan rộng toàn hệ thống (phải hỏi ý kiến người dùng để confirm nếu định chạy full suite). Bắt buộc phải có cờ `--filter`. Nếu quên, dừng lại và hỏi người dùng.
Sử dụng format xuất báo cáo mặc định: `--coverage-html` và `--coverage-clover`.

Lệnh chạy ví dụ:
```bash
XDEBUG_MODE=coverage vendor/bin/phpunit --filter TênTestClass --coverage-html coverage-report/ --coverage-clover coverage.xml
```
Sau khi tạo báo cáo, mở thư mục HTML tương tác cho người dùng (ví dụ dùng lệnh `start coverage-report/index.html` hoặc tương đương tùy OS).

## 5. Vòng lặp cải thiện độ phủ (Loop-until-90)

Đọc file báo cáo `coverage.xml` (chuẩn Clover).
Chỉ lọc và phân tích số đếm (statements, methods, elements) đối với các file và method cụ thể đã bị ảnh hưởng hoặc nằm trong target.
Tính toán tỷ lệ phần trăm: `(covered elements / total elements) * 100`.
Điều kiện đạt: Tỷ lệ lớn hơn 90% cho phần mã bị ảnh hưởng.
Nếu chưa đạt, chỉ sửa và bổ sung test case, sau đó chạy lại lệnh test có coverage.
Sau mỗi vòng lặp, đóng gói bằng chứng (evidence) vào file nén: nén thư mục `coverage-report/`, file `coverage.xml` và file log lỗi/output vào file `evidence/php-loop-<vong>.zip`.
Giới hạn tối đa 5 vòng lặp. Ở mỗi vòng, ghi nhật ký: Số thứ tự vòng lặp / Tỷ lệ coverage còn thiếu / Các nhánh chưa được phủ.

## 6. Dừng và xin ý kiến (Stop-and-ask)

Dừng vòng lặp và hỏi người dùng nếu thỏa mãn một trong các điều kiện dừng thật:
- Phát hiện lỗi logic nghiệp vụ nghiêm trọng có thể ảnh hưởng production.
- Mã nguồn không thể viết test (untestable code) do thiết kế (statics, deps lằng nhằng).
- Coverage không tăng trong 2 vòng lặp liên tiếp.
- Thiếu cờ `--filter` hoặc tính chạy full suite.
Khi dừng, trình bày rõ câu hỏi cùng với bằng chứng cụ thể từ logs hoặc code.

## Output

```markdown
# PHP Impact Test Loop Result

## Bảng phân tích ảnh hưởng (Impact table)
| File | Hàm | API | Mức độ rủi ro (HIGH/MED/LOW) |
|------|-----|-----|------------------------------|

## Danh sách cần kiểm tra (Retest list)
- Class.method1 (Lý do chọn)
- Class.method2 (Lý do chọn)

## Kết quả PHPUnit (Coverage result)
- Statements: X%
- Methods: Y%
- Elements: Z%

## Nhật ký vòng lặp
- Vòng 1: Đạt X% elements. Thiếu: Nhánh kiểm tra null. Evidence: `evidence/php-loop-1.zip`
- Vòng 2: Đạt Y% elements. Thiếu: Nhánh kiểm tra ngoại lệ. Evidence: `evidence/php-loop-2.zip`
```

## Safety boundaries

- Không chỉnh sửa mã nguồn chính (thư mục `src`/`app`) trong quá trình chạy test loop chỉ để dễ test.
- Không hạ thấp ngưỡng coverage yêu cầu (90%).
- Không xóa các test case cũ chỉ để làm tăng tỷ lệ coverage ảo.
- Không tự ý commit hoặc push mã nguồn khi chưa có yêu cầu từ người dùng.
