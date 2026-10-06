---
name: php-impact-unittest-loop
description: 'Phân tích vùng ảnh hưởng, tự động tạo test case PHPUnit và chạy lặp để đạt 90% coverage cho mã nguồn PHP.'
---

# PHP Impact Unittest Loop

Sử dụng skill này sau khi đã hoàn tất thay đổi mã nguồn PHP và người dùng yêu cầu kiểm tra lại (retest), đánh giá ảnh hưởng (impact), hoặc nâng cao độ phủ (coverage).

## 1. Phân tích vùng ảnh hưởng (Impact)

Sử dụng `git status` và `git diff -U0` để phân loại các file mã nguồn và các dòng mã (lines) đã thay đổi.
So khớp các thay đổi từ git diff với cấu trúc file PHP để xác định chính xác Class và Method bị sửa đổi.
Lập bảng đánh giá mức độ ảnh hưởng: File / Hàm (Method) / API tương ứng / Mức độ rủi ro (HIGH/MED/LOW).

## 2. Xác định mục tiêu cần kiểm tra (Target)

Chỉ định các hàm, API cụ thể cần viết test dựa trên quy tắc sau:
- Bao gồm các hàm/method bị thay đổi trực tiếp (xác định từ bước 1).
- Bao gồm các hàm gọi đến (callers) hoặc được gọi từ (callees) hàm thay đổi với khoảng cách 1 hop.
- Bao gồm các API/Controller handler liên quan trực tiếp đến luồng logic thay đổi.
- Loại trừ các đoạn mã sinh tự động, boilerplate framework, hoặc file migration/config.

## 3. Tạo bài kiểm tra (Tạo test)

Viết các bài kiểm tra bằng PHPUnit.
Đặt file test tại thư mục `tests/` (ví dụ `tests/Unit/` hoặc `tests/Feature/`) phản chiếu cấu trúc thư mục mã nguồn (`src/` hoặc `app/`). Tên file test phải có hậu tố `Test.php`.
Giả lập các phụ thuộc bên ngoài bằng `createMock()` hoặc `createStub()` của PHPUnit (hoặc Mockery nếu dự án yêu cầu).
Mỗi nhánh logic (branch/if-else) bị thay đổi phải có test case bao phủ:
- Đường dẫn chuẩn (happy path)
- Giá trị null hoặc không hợp lệ
- Bắn lỗi (Exception)
- Boundary values (giá trị biên)

## 4. Chạy kiểm tra chọn lọc (Chạy selective)

Chỉ chạy test cho các Class/Method bị ảnh hưởng bằng cờ `--filter`. Tránh chạy toàn bộ test suite.
Bật extension thu thập coverage (Xdebug hoặc PCOV) để lấy kết quả đo lường.
- Sử dụng PCOV: `php -d pcov.enabled=1 vendor/bin/phpunit --filter "TestClassName" --coverage-clover clover.xml --coverage-html coverage/`
- Sử dụng Xdebug: `XDEBUG_MODE=coverage vendor/bin/phpunit --filter "TestClassName" --coverage-clover clover.xml --coverage-html coverage/`

## 5. Vòng lặp cải thiện độ phủ (Loop-until-90)

Đọc file báo cáo `clover.xml`. Tìm các thẻ `<file>` và `<class>`, `<line>` hoặc `<metrics>` tương ứng với file/hàm đã sửa.
Đánh giá tỷ lệ phần trăm Statements (dòng lệnh) và Methods. Phép tính: `(coveredstatements / statements) * 100`.
Điều kiện đạt: Tỷ lệ Statements (Line coverage) và Branch/Path coverage (nếu có) lớn hơn 90%.
Nếu chưa đạt 90%, bổ sung test case cho các trường hợp còn thiếu (dòng code không được hit), sau đó chạy lại lệnh PHPUnit với `--filter` và `--coverage-clover`.
Giới hạn tối đa 5 vòng lặp. Ở mỗi vòng, ghi log: Số thứ tự vòng / % coverage còn thiếu / Dòng (Lines) cụ thể chưa được phủ.

## 6. Hoàn tất hoặc dừng (Stop-and-ask)

Dừng vòng lặp và hỏi người dùng nếu gặp một trong các điều kiện:
- Phát hiện lỗi logic nghiệp vụ làm hỏng ứng dụng.
- Mã nguồn cũ quá phức tạp hoặc có dependency ngầm (hidden dependencies) khiến việc mock thất bại (untestable code).
- Coverage không cải thiện sau 2 vòng lặp liên tiếp.
Khi hoàn tất quy trình (thành công đạt 90% hoặc buộc dừng theo điều kiện trên), nén báo cáo thành file ZIP một lần duy nhất tại `evidence/php-final-coverage.zip`. Không nén file qua mỗi vòng lặp.
Khi dừng sớm, trình bày rõ nguyên nhân kèm theo thông báo lỗi từ PHPUnit hoặc đoạn mã gây tắc nghẽn.

## Output

```markdown
# PHP Impact Test Loop Result

## Bảng phân tích ảnh hưởng (Impact table)
| File | Hàm (Method) | API | Mức độ rủi ro (HIGH/MED/LOW) |
|------|--------------|-----|------------------------------|

## Danh sách cần kiểm tra (Retest list)
- ClassName::method1 (Lý do chọn)
- ClassName::method2 (Lý do chọn)

## Kết quả Clover (Coverage result)
- Statements: X%
- Methods: Y%
- Tình trạng: ĐẠT/CHƯA ĐẠT (Ngưỡng 90%)

## Nhật ký vòng lặp
- Vòng 1: Đạt X% Statements. Thiếu: Nhánh if ở dòng 45.
- Vòng 2: Đạt Y% Statements. Thiếu: Bắt Exception ở dòng 60.
```

## Safety boundaries

- Không tự ý sửa đổi code gốc trong `src/` hoặc `app/` chỉ để bypass test (trừ khi được user đồng ý fix bug).
- Không sửa file cấu hình `phpunit.xml` làm giảm tiêu chuẩn coverage của dự án.
- Giữ nguyên cấu trúc thư mục, chỉ thêm file vào thư mục `tests/`.
- Không tự ý commit/push mã nguồn.
