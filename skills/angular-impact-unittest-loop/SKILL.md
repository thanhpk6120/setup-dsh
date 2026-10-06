---
name: angular-impact-unittest-loop
description: 'Phân tích vùng ảnh hưởng, tự động tạo test case Jasmine/Karma và chạy lặp để đạt 90% coverage cho mã nguồn Angular.'
---

# Angular Impact Unittest Loop

Sử dụng skill này sau khi đã hoàn tất thay đổi mã nguồn Angular và người dùng yêu cầu kiểm tra lại (retest), đánh giá ảnh hưởng (impact), hoặc nâng cao độ phủ (coverage).

## Giới hạn hệ thống (Limitation)

Angular CLI (`ng test --code-coverage`) sử dụng Karma và Istanbul (`karma-coverage`). Karma lọc test theo glob pattern thông qua tham số `--include`, báo cáo coverage mặc định xuất ra `coverage/<project-name>/index.html` và `coverage/<project-name>/lcov.info`.
Công cụ không hỗ trợ sẵn bộ lọc độ phủ theo từng method thay đổi (method-changed filter). Do đó:
- Phải ánh xạ thủ công từ `git diff` sang các file spec, component hoặc method tương ứng.
- Sử dụng `--include` selective để chỉ chạy các spec liên quan.
- Đọc và lọc file `lcov.info` theo từng hàm liên quan git diff để tính toán coverage chính xác cho phần bị ảnh hưởng.
- Giữ nguyên format mặc định của Karma HTML và LCOV, không dùng reporter tùy biến (custom reporter).

## 1. Phân tích vùng ảnh hưởng (Impact)

Sử dụng `git status` hoặc `git diff --name-only` để phân loại các file mã nguồn Angular đã thay đổi.
Nếu có GitNexus MCP, dùng lệnh `impact/context/trace` để quét đồ thị phụ thuộc.
Nếu không, phân tích thủ công theo thứ tự: `component -> service -> pipe/directive -> model/state`.
Lập bảng đánh giá mức độ ảnh hưởng: File / Hàm / Component hoặc Service / Mức độ rủi ro (HIGH/MED/LOW).

## 2. Xác định mục tiêu cần kiểm tra (Target)

Chỉ định các hàm, component, service cụ thể cần viết test dựa trên quy tắc sau:
- Bao gồm các hàm, phương thức bị thay đổi trực tiếp theo `git diff`.
- Bao gồm các component hoặc service gọi đến (callers) hoặc được gọi từ (callees) hàm thay đổi với khoảng cách 1 hop.
- Loại trừ các file cấu hình hệ thống (`environment.*.ts`, config module) hoặc file sinh tự động.
- Tìm hoặc tạo file test tương ứng (`*.spec.ts`) cho từng target.
- Tương tác với người dùng: Nếu không tìm thấy file spec tương ứng hoặc thiếu target `--include`, dừng lại và hỏi người dùng xác nhận đường dẫn spec cần chạy.

## 3. Tạo bài kiểm tra (Tạo test)

Viết các bài kiểm tra bằng Jasmine và Karma. Đặt file test cùng thư mục với file mã nguồn tương ứng (`.spec.ts`).
- **Setup TestBed**: Khai báo `TestBed.configureTestingModule` với các module, component, providers cần thiết.
- **Mock Service**: Dùng `jasmine.createSpyObj('ServiceName', ['methodName'])` để tạo mock service, tránh gọi đến service thật. Dùng `mockService.methodName.and.returnValue(...)` để giả lập kết quả.
- Mỗi nhánh logic (branch) bị thay đổi phải có ít nhất một test case tương ứng:
  - Đường dẫn chuẩn (happy path)
  - Các trường hợp rẽ nhánh (if/else, switch/case)
  - Xử lý lỗi (error từ API, dữ liệu đầu vào sai, exception)
  - Dữ liệu trống (empty) hoặc null/undefined

## 4. Chạy kiểm tra chọn lọc (Chạy selective)

Thực thi test riêng lẻ trên các file vừa tạo hoặc thay đổi, cấm chạy toàn bộ test suite trừ khi vùng ảnh hưởng lan rộng toàn hệ thống.
- Sử dụng lệnh: `ng test --include="src/app/path/to/target.spec.ts" --no-watch --code-coverage`
- Tương tác với người dùng: Nếu vùng ảnh hưởng lan rộng và cần chạy toàn bộ test suite (`ng test --no-watch --code-coverage`), bắt buộc phải hỏi xin xác nhận (confirm) từ người dùng trước khi thực thi.

## 5. Vòng lặp cải thiện độ phủ (Loop-until-90)

Đọc file báo cáo mặc định `coverage/<project-name>/lcov.info` hoặc mở `coverage/<project-name>/index.html`.
- Thu thập các chỉ số: Functions (FN/FNDA), Lines (LF/LH), Branches (BRF/BRH) chỉ đối với các hàm liên quan đến git diff.
- Tính toán tỷ lệ phần trăm: `(covered / total) * 100`.
- Điều kiện đạt: Tỷ lệ lớn hơn 90% ở các chỉ số Functions, Lines, và Branches của các hàm bị ảnh hưởng.
- Tương tác mở báo cáo trực quan: Mở file `coverage/<project-name>/index.html` trên trình duyệt sau mỗi vòng lặp.
- Nếu chưa đạt, chỉ sửa và bổ sung test case, sau đó chạy lại lệnh test selective.
- Giới hạn tối đa 5 vòng lặp. Ở mỗi vòng, ghi nhật ký: Số thứ tự vòng lặp / Tỷ lệ coverage còn thiếu / Các nhánh chưa được phủ.
- Lưu trữ bằng chứng (evidence): Nén thư mục `coverage/` và log Karma thành file `evidence/angular-loop-<vong>.zip` (ví dụ `evidence/angular-loop-1.zip`).

## 6. Dừng và xin ý kiến (Stop-and-ask)

Dừng vòng lặp và hỏi người dùng nếu thỏa mãn một trong các điều kiện:
- Phát hiện lỗi logic nghiệp vụ nghiêm trọng có thể ảnh hưởng production.
- Mã nguồn không thể viết test (untestable code) do thiết kế kiến trúc hoặc dependency phức tạp.
- Coverage không tăng trong 2 vòng lặp liên tiếp.
- Thiếu target `--include` hoặc cần xác nhận chạy full test suite.
Khi dừng, trình bày rõ câu hỏi cùng với bằng chứng cụ thể từ logs hoặc code.

## Output

Chỉ báo cáo các hàm liên quan git diff:

```markdown
# Angular Impact Test Loop Result

## Bảng phân tích ảnh hưởng (Impact table)
| File | Hàm / Phương thức | Component / Service | Mức độ rủi ro (HIGH/MED/LOW) |
|------|-------------------|---------------------|------------------------------|

## Danh sách cần kiểm tra (Retest list)
- Component.method1 (Lý do chọn)
- Service.method2 (Lý do chọn)

## Kết quả Coverage (Chỉ hàm liên quan Git)
- Statements: X%
- Branches: Y%
- Functions: Z%
- Lines: W%

## Bằng chứng kiểm thử (Evidence)
- File báo cáo: coverage/<project-name>/index.html
- File nén bằng chứng: evidence/angular-loop-1.zip

## Nhật ký vòng lặp
- Vòng 1: Đạt X% nhánh. Thiếu: Nhánh kiểm tra null/undefined.
- Vòng 2: Đạt Y% nhánh. Thiếu: Xử lý lỗi HttpErrorResponse.
```

## Safety boundaries

- Không chỉnh sửa mã nguồn nghiệp vụ trong `src/app` trong quá trình chạy test loop.
- Không hạ thấp ngưỡng coverage yêu cầu (90%).
- Không xóa các test case cũ chỉ để làm tăng tỷ lệ coverage ảo.
- Không tự ý commit hoặc push mã nguồn khi chưa có yêu cầu từ người dùng.
- Giữ nguyên cấu hình định dạng report mặc định của karma/istanbul (HTML và LCOV), không tùy biến reporter.
