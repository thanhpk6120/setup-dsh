---
name: dotnet-impact-unittest-loop
description: 'Phân tích vùng ảnh hưởng, tự động tạo test case xUnit/Moq và chạy lặp để đạt 90% coverage cho mã nguồn .NET.'
---

# .NET Impact Unittest Loop

Sử dụng skill này sau khi đã hoàn tất thay đổi mã nguồn .NET và người dùng yêu cầu kiểm tra lại (retest), đánh giá ảnh hưởng (impact), hoặc nâng cao độ phủ (coverage).

**Giới hạn của .NET Coverage**: Công cụ `.NET` (`dotnet test --collect "XPlat Code Coverage"` với `coverlet` và `ReportGenerator`) không hỗ trợ sẵn việc tự động lọc coverage chỉ cho các hàm bị thay đổi (changed-methods). Do đó, phải kết hợp `git diff` để ánh xạ tới C# class/method, dùng `--filter` để chạy test chọn lọc, và tự parse file `coverage.cobertura.xml` (trong thư mục `TestResults`) để lấy coverage cho method tương ứng. `ReportGenerator` sinh HTML mặc định, không cần template custom.

## 1. Phân tích vùng ảnh hưởng (Impact)

Sử dụng `git status` hoặc `git diff --name-only` để phân loại các file mã nguồn đã thay đổi.
Nếu có GitNexus MCP, dùng lệnh `impact/context/trace` để quét đồ thị phụ thuộc.
Nếu không, phân tích thủ công theo thứ tự đọc các lớp (Layer): `Controller -> Service -> Repository -> Entity`.
Lập bảng đánh giá mức độ ảnh hưởng: File / Hàm / API tương ứng / Mức độ rủi ro (HIGH/MED/LOW).

## 2. Xác định mục tiêu cần kiểm tra (Target)

Chỉ định các hàm, API cụ thể cần viết test dựa trên quy tắc sau:
- Bao gồm các hàm bị thay đổi trực tiếp (dựa theo `git diff`).
- Bao gồm các hàm gọi đến (callers) hoặc được gọi từ (callees) hàm thay đổi với khoảng cách 1 hop.
- Bao gồm các API handler liên quan trực tiếp đến luồng logic thay đổi.
- Loại trừ các đoạn mã được sinh tự động (generated code) hoặc các lớp cấu hình hệ thống (config).

## 3. Tạo bài kiểm tra (Tạo test)

Viết các bài kiểm tra bằng xUnit và Moq.
Đặt test class tương ứng với cấu trúc thư mục của source code. Tên file test phải có hậu tố `Tests`.
Giả lập (mock) các đường ranh giới hệ thống như Database, HTTP client, hoặc Message Queue.
Mỗi nhánh logic (branch) bị thay đổi phải có ít nhất một test case tương ứng:
- Đường dẫn chuẩn (happy path)
- Giá trị null
- Dữ liệu trống (empty)
- Bắn lỗi (exception)
- Cấp quyền (permission)
Sử dụng `[Fact]` cho một test case đơn và `[Theory]` với `[InlineData]` cho kiểm thử tham số hóa.

## 4. Chạy kiểm tra chọn lọc (Chạy selective)

Thực thi test riêng lẻ trên các file vừa tạo hoặc thay đổi, cấm chạy toàn bộ test suite trừ khi vùng ảnh hưởng lan rộng toàn hệ thống. Cần xác nhận với người dùng trước khi chạy toàn bộ suite hoặc nếu thiếu cờ `--filter`.
Sử dụng lệnh chạy selective test và thu thập coverage bằng coverlet:
```bash
dotnet test --filter "FullyQualifiedName~Namespace.TestClass" --collect:"XPlat Code Coverage"
```

## 5. Vòng lặp cải thiện độ phủ (Loop-until-90)

Sinh báo cáo bằng ReportGenerator (giữ nguyên template HTML mặc định):
```bash
reportgenerator -reports:"**/coverage.cobertura.xml" -targetdir:"coveragereport" -reporttypes:"Html;TextSummary"
```
Đọc file báo cáo `coverage.cobertura.xml` trong `TestResults`. Sử dụng script để lọc và tính toán Tỷ lệ coverage theo dòng (Line) và nhánh (Branch) cho chính xác method/class bị thay đổi.
Điều kiện đạt: Tỷ lệ lớn hơn 90% ở Line và Branch.
Nếu chưa đạt, chỉ sửa và bổ sung test case, sau đó chạy lại lệnh test và gen report.
Giới hạn tối đa 5 vòng lặp. 
Ở mỗi vòng: 
- Ghi nhật ký: Số thứ tự vòng lặp / Tỷ lệ coverage còn thiếu / Các nhánh chưa được phủ.
- Mở file `coveragereport/index.html` cho người dùng xem nếu cần bằng lệnh OS (start/open).
- Đóng gói bằng chứng (evidence): Nén thư mục `TestResults`, `coveragereport`, và test log thành file `evidence/dotnet-loop-<vong>.zip`.

## 6. Dừng và xin ý kiến (Stop-and-ask)

Dừng vòng lặp và hỏi người dùng nếu thỏa mãn một trong các điều kiện dừng thật:
- Phát hiện lỗi logic nghiệp vụ nghiêm trọng có thể ảnh hưởng production.
- Mã nguồn không thể viết test (untestable code) do thiết kế (ví dụ không thể mock dependency, private state phức tạp).
- Coverage không tăng trong 2 vòng lặp liên tiếp hoặc chạm mốc 3-5 iterations mà không đạt.
Khi dừng, trình bày rõ câu hỏi cùng với bằng chứng cụ thể từ logs hoặc code.

## Output

```markdown
# .NET Impact Test Loop Result

## Bảng phân tích ảnh hưởng (Impact table)
| File | Hàm | API | Mức độ rủi ro (HIGH/MED/LOW) |
|------|-----|-----|------------------------------|

## Danh sách cần kiểm tra (Retest list)
- Class.Method1 (Lý do chọn)
- Class.Method2 (Lý do chọn)

## Kết quả Coverage (.NET)
- Line Coverage: X%
- Branch Coverage: Z%

## Nhật ký vòng lặp
- Vòng 1: Đạt X% nhánh. Thiếu: Nhánh kiểm tra null. Evidence: evidence/dotnet-loop-1.zip
- Vòng 2: Đạt Y% nhánh. Thiếu: Nhánh kiểm tra ngoại lệ. Evidence: evidence/dotnet-loop-2.zip
```

## Safety boundaries

- Không chỉnh sửa mã nguồn gốc trong quá trình chạy test loop.
- Không hạ thấp ngưỡng coverage yêu cầu (90%).
- Không xóa các test case cũ chỉ để làm tăng tỷ lệ coverage ảo.
- Không tự ý commit hoặc push mã nguồn khi chưa có yêu cầu từ người dùng.