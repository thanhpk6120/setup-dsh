---
name: dotnet-impact-unittest-loop
description: 'Phân tích vùng ảnh hưởng, tự động tạo test case xUnit/Moq (hoặc NSubstitute) và chạy lặp để đạt 90% coverage cho mã nguồn .NET.'
---

# .NET Impact Unittest Loop

Sử dụng skill này sau khi đã hoàn tất thay đổi mã nguồn .NET (C#) và người dùng yêu cầu kiểm tra lại (retest), đánh giá ảnh hưởng (impact), hoặc nâng cao độ phủ (coverage).

## 1. Phân tích vùng ảnh hưởng (Impact)

Sử dụng `git status` hoặc `git diff` để xác định các file `.cs` đã thay đổi.
Map thay đổi trong diff tới method cụ thể:
- Dùng `git diff -U0` hoặc `git diff -W` để đọc hunk header chứa tên method C# thay đổi.
- Nếu có GitNexus MCP, dùng lệnh `impact/context/trace` để quét đồ thị phụ thuộc.
- Nếu phân tích thủ công, lần theo kiến trúc Clean Architecture / N-Tier: `Controller/Endpoints -> Application/Service -> Domain/Entities -> Infrastructure/Repository`.
Lập bảng đánh giá mức độ ảnh hưởng: File / Hàm / API tương ứng / Mức độ rủi ro (HIGH/MED/LOW).

## 2. Xác định mục tiêu cần kiểm tra (Target)

Chỉ định các hàm, API cụ thể cần viết test dựa trên quy tắc sau:
- Bao gồm các hàm bị thay đổi trực tiếp (Direct changes).
- Bao gồm các callers hoặc callees của hàm thay đổi với khoảng cách 1 hop.
- Bao gồm các API Endpoint/Handler liên quan trực tiếp đến luồng logic thay đổi.
- Loại trừ boilerplate, DTO thuần, migrations và cấu hình DI (`Program.cs`, `Startup.cs`).

## 3. Tạo bài kiểm tra (Tạo test)

Viết các bài kiểm tra bằng **xUnit** kết hợp **Moq** (hoặc **NSubstitute**).
Đặt file test tại project test tương ứng (VD: `tests/{Project}.UnitTests`) phản chiếu namespace của project nguồn. Hậu tố file test là `Tests.cs`.
Mỗi method bị ảnh hưởng phải được phủ các nhánh logic:
- `[Fact]`: Đường dẫn chuẩn (Happy path), giá trị null/empty, ngoại lệ ném ra (`Assert.ThrowsAsync<T>`).
- `[Theory]` + `[InlineData]` / `[MemberData]`: Kiểm thử biên và các bộ tham số khác nhau.
- Giả lập ranh giới hệ thống: DbContext, HttpClient, external services qua Interface.

## 4. Chạy kiểm tra chọn lọc (Chạy selective)

Cấm chạy toàn bộ test suite trừ khi vùng ảnh hưởng lan toàn hệ thống.
Chạy test chọn lọc bằng `--filter FullyQualifiedName`:
```bash
dotnet test --filter "FullyQualifiedName~{Namespace}.{TestClassName}" --collect "XPlat Code Coverage"
```
Coverlet tự động xuất file báo cáo mặc định tại `TestResults/{guid}/coverage.cobertura.xml`.

## 5. Vòng lặp cải thiện độ phủ (Loop-until-90)

1. **Đọc coverage theo method**:
   Truy xuất `line-rate` và `branch-rate` trực tiếp từ thẻ `<method>` trong `coverage.cobertura.xml`.
2. **Sinh HTML report khi cần xem chi tiết trực quan**:
   Sử dụng ReportGenerator để xuất báo cáo:
   `reportgenerator -reports:"**/coverage.cobertura.xml" -targetdir:"coveragereport" -reporttypes:Html`
3. **Tiêu chuẩn đạt**:
   Cả `line-rate` và `branch-rate` của method bị ảnh hưởng đạt >= 0.90 (90%).
4. **Vòng lặp (tối đa 5 lần)**:
   Nếu chưa đạt 90%, kiểm tra các line/branch có `hits="0"`, bổ sung test case tương ứng, sau đó chạy lại selective test.
   Ghi nhật ký mỗi vòng: Số thứ tự / % line & branch coverage / Nhánh còn thiếu.

## 6. Dừng và xin ý kiến (Stop-and-ask)

Dừng vòng lặp và hỏi người dùng nếu gặp một trong các điều kiện:
- Phát hiện lỗi logic nghiệp vụ nghiêm trọng có thể phá vỡ contract API hoặc data flow.
- Code không thể viết test do thiết kế (Untestable: static state, thiếu interface, constructor khởi tạo trực tiếp new instance phụ thuộc bên ngoài).
- Coverage không tăng qua 2 vòng lặp liên tiếp.
Trình bày rõ file, method, nguyên nhân và đề xuất phương án.

## Output

```markdown
# .NET Impact Test Loop Result

## Bảng phân tích ảnh hưởng (Impact table)
| File | Hàm | API | Mức độ rủi ro (HIGH/MED/LOW) |
|------|-----|-----|------------------------------|

## Danh sách cần kiểm tra (Retest list)
- Class.Method1 (Lý do chọn)
- Class.Method2 (Lý do chọn)

## Kết quả Coverage (Coverlet/Cobertura result)
- Method: Namespace.Class.Method
  - Line Coverage: X%
  - Branch Coverage: Y%

## Nhật ký vòng lặp
- Vòng 1: Đạt X% line / Y% branch. Thiếu: Nhánh kiểm tra ArgumentNullException.
- Vòng 2: Đạt 95% line / 92% branch. Đã bổ sung Theory kiểm thử giá trị rỗng.
```

## Safety boundaries

- Không sửa source code trong project chính (`src/`) trong quá trình chạy test loop.
- Không hạ thấp ngưỡng coverage yêu cầu (90%).
- Không xóa hoặc vô hiệu hóa (`[Fact(Skip="...")]`) test case cũ để tăng coverage ảo.
- Không commit hay push mã nguồn khi chưa được yêu cầu.
