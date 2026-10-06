---
name: java-impact-unittest-loop
description: 'Phân tích vùng ảnh hưởng, tự động tạo test case JUnit/Mockito và chạy lặp để đạt 90% coverage cho mã nguồn Java.'
---

# Java Impact Unittest Loop

Sử dụng skill này sau khi đã hoàn tất thay đổi mã nguồn Java và người dùng yêu cầu kiểm tra lại (retest), đánh giá ảnh hưởng (impact), hoặc nâng cao độ phủ (coverage).

## 1. Phân tích vùng ảnh hưởng (Impact)

Sử dụng `git status` hoặc `git diff --name-only` để phân loại các file mã nguồn đã thay đổi.
Nếu có GitNexus MCP, dùng lệnh `impact/context/trace` để quét đồ thị phụ thuộc.
Nếu không, phân tích thủ công theo thứ tự đọc các lớp (Layer): `controller -> service -> repository -> entity`.
Lập bảng đánh giá mức độ ảnh hưởng: File / Hàm / API tương ứng / Mức độ rủi ro (HIGH/MED/LOW).

## 2. Xác định mục tiêu cần kiểm tra (Target)

Chỉ định các hàm, API cụ thể cần viết test dựa trên quy tắc sau:
- Bao gồm các hàm bị thay đổi trực tiếp.
- Bao gồm các hàm gọi đến (callers) hoặc được gọi từ (callees) hàm thay đổi với khoảng cách 1 hop.
- Bao gồm các API handler liên quan trực tiếp đến luồng logic thay đổi.
- Loại trừ các đoạn mã được sinh tự động (generated code) hoặc các lớp cấu hình hệ thống (config).

## 3. Tạo bài kiểm tra (Tạo test)

Viết các bài kiểm tra bằng JUnit5 và Mockito.
Đặt file test tại thư mục `src/test` với cấu trúc package phản chiếu chính xác thư mục `src/main`. Tên file test phải có hậu tố `Test`.
Giả lập (mock) các đường ranh giới hệ thống như Database, HTTP client, hoặc Message Queue.
Mỗi nhánh logic (branch) bị thay đổi phải có ít nhất một test case tương ứng:
- Đường dẫn chuẩn (happy path)
- Giá trị null
- Dữ liệu trống (empty)
- Bắn lỗi (exception)
- Quyền truy cập (permission)

## 4. Chạy kiểm tra chọn lọc (Chạy selective)

Thực thi test riêng lẻ trên các file vừa tạo hoặc thay đổi, cấm chạy toàn bộ test suite trừ khi vùng ảnh hưởng lan rộng toàn hệ thống.
Với Maven: sử dụng lệnh `mvn -Dtest=[TênTestClass] -Dsurefire.failIfNoSpecifiedTests=false test`, sau đó chạy `mvn jacoco:report`.
Với Gradle: sử dụng lệnh `gradle test --tests "[Package.TênTestClass]"`, sau đó chạy `gradle jacocoTestReport`.

## 5. Vòng lặp cải thiện độ phủ (Loop-until-90)

Đọc file báo cáo `target/site/jacoco/jacoco.xml` hoặc `build/reports/jacoco/test/jacocoTestReport.xml`.
Thu thập các số đếm (counter): INSTRUCTION, LINE, BRANCH (MISSED và COVERED) đối với các lớp bị ảnh hưởng.
Tính toán tỷ lệ phần trăm (COVERED / (MISSED + COVERED)).
Điều kiện đạt: Tỷ lệ lớn hơn 90% ở cả 3 loại counter, hoặc tối thiểu ở INSTRUCTION và BRANCH.
Nếu chưa đạt, chỉ sửa và bổ sung test case, sau đó chạy lại lệnh test và jacoco.
Giới hạn tối đa 5 vòng lặp. Ở mỗi vòng, ghi nhật ký: Số thứ tự vòng lặp / Tỷ lệ coverage còn thiếu / Các nhánh (branch) chưa được phủ.

## 6. Dừng và xin ý kiến (Stop-and-ask)

Dừng vòng lặp và hỏi người dùng nếu thỏa mãn một trong các điều kiện dừng thật:
- Phát hiện lỗi logic nghiệp vụ nghiêm trọng có thể ảnh hưởng production.
- Mã nguồn không thể viết test (untestable code) do thiết kế.
- Coverage không tăng trong 2 vòng lặp liên tiếp.
Khi dừng, trình bày rõ câu hỏi cùng với bằng chứng cụ thể từ logs hoặc code.

## 7. Đóng gói kết quả (Zip evidence)

Việc tạo ZIP phải là bước cuối cùng sau khi thoát khỏi vòng lặp cải thiện độ phủ.
Tạo thư mục `evidence/` và nén thư mục báo cáo JaCoCo (ví dụ: `target/site/jacoco/` hoặc `build/reports/jacoco/`) với tên file là `evidence/java-final-coverage.zip`.

## Output

```markdown
# Java Impact Test Loop Result

## Bảng phân tích ảnh hưởng (Impact table)
| File | Hàm | API | Mức độ rủi ro (HIGH/MED/LOW) |
|------|-----|-----|------------------------------|

## Danh sách cần kiểm tra (Retest list)
- Class.method1 (Lý do chọn)
- Class.method2 (Lý do chọn)

## Kết quả JaCoCo (JaCoCo result)
- INSTRUCTION: X%
- LINE: Y%
- BRANCH: Z%

## Nhật ký vòng lặp
- Vòng 1: Đạt X% nhánh. Thiếu: Nhánh kiểm tra null.
- Vòng 2: Đạt Y% nhánh. Thiếu: Nhánh kiểm tra ngoại lệ.

## Bằng chứng kiểm thử (Evidence)
- Nén bằng chứng: evidence/java-final-coverage.zip
```

## Safety boundaries

- Không chỉnh sửa mã nguồn trong `src/main` trong quá trình chạy test loop.
- Không hạ thấp ngưỡng coverage yêu cầu (90%).
- Không xóa các test case cũ chỉ để làm tăng tỷ lệ coverage ảo.
- Không tự ý commit hoặc push mã nguồn khi chưa có yêu cầu từ người dùng.