---
name: angular-impact-unittest-loop
description: 'Phân tích vùng ảnh hưởng, tự động tạo test case Jasmine/Karma và chạy lặp để đạt 90% coverage cho mã nguồn Angular.'
---

# Angular Impact Unittest Loop

Sử dụng skill này sau khi đã hoàn tất thay đổi mã nguồn Angular và người dùng yêu cầu kiểm tra lại (retest), đánh giá ảnh hưởng (impact), hoặc nâng cao độ phủ (coverage).

## 1. Phân tích vùng ảnh hưởng (Impact)

Sử dụng `git status` hoặc `git diff -U0` để phân loại các file mã nguồn đã thay đổi và map chính xác tới các component, service hoặc method tương ứng.
Nếu có GitNexus MCP, dùng lệnh `impact/context/trace` để quét đồ thị phụ thuộc.
Lập bảng đánh giá mức độ ảnh hưởng: File / Hàm / Component hoặc Service / Mức độ rủi ro (HIGH/MED/LOW).

## 2. Xác định mục tiêu cần kiểm tra (Target)

Chỉ định các hàm, component cụ thể cần viết test dựa trên quy tắc sau:
- Bao gồm các hàm bị thay đổi trực tiếp.
- Bao gồm component/service gọi đến (callers) hoặc được gọi từ (callees) hàm thay đổi với khoảng cách 1 hop.
- Tương tác với người dùng: Bắt buộc hỏi và xác nhận nếu phải mở rộng vùng chạy test hoặc chạy toàn bộ file.

## 3. Tạo bài kiểm tra (Tạo test)

Viết các bài kiểm tra bằng Jasmine và Angular `TestBed`.
Đặt file test tại cùng thư mục với file mã nguồn (`.spec.ts`).
- Dùng `TestBed.configureTestingModule` để setup module.
- Giả lập (mock) dependencies (Services, Router, HttpClient) thông qua `jasmine.createSpyObj`.
Mỗi nhánh logic (branch) bị thay đổi phải có ít nhất một test case tương ứng:
- Đường dẫn chuẩn (happy path)
- Giá trị null/undefined, dữ liệu trống (empty)
- Bắn lỗi (exception/HttpErrorResponse)
- Trạng thái rẽ nhánh (if/else)

## 4. Chạy kiểm tra chọn lọc (Chạy selective)

Thực thi test riêng lẻ trên các file vừa tạo hoặc thay đổi. Không chạy toàn bộ test suite.
Lệnh chạy: `ng test --include="<đường_dẫn_file_spec>" --no-watch --code-coverage --browsers=ChromeHeadless`
Nếu cần chạy toàn bộ suite, phải xin xác nhận từ người dùng.

## 5. Vòng lặp cải thiện độ phủ (Loop-until-90)

Đọc file báo cáo coverage sinh ra mặc định tại `coverage/<project-name>/lcov.info` hoặc `coverage/<project-name>/index.html`.
Thu thập các chỉ số `Lines`, `Functions`, và `Branches` tương ứng với các hàm bị thay đổi theo git diff.
Điều kiện đạt: Tỷ lệ coverage đạt 90% đối với các hàm thay đổi trên cả 3 chỉ số.
Nếu chưa đạt, chỉ sửa và bổ sung test case, chạy lại `ng test selective` và kiểm tra lại lcov.
Giới hạn tối đa 5 vòng lặp. Ở mỗi vòng, ghi nhật ký: Số thứ tự vòng / Tỷ lệ coverage hiện tại / Nhánh (branch) thiếu.

## 6. Dừng và xin ý kiến (Stop-and-ask)

Dừng vòng lặp và hỏi người dùng nếu:
- Phát hiện lỗi logic nghiệp vụ nghiêm trọng.
- Mã nguồn khó hoặc không thể test (untestable code) do dependency ẩn hoặc thiết kế.
- Coverage không thay đổi/tăng trong 2 vòng lặp liên tiếp.
Trình bày rõ câu hỏi cùng logs hoặc code chứng minh.

## Output

```markdown
# Angular Impact Test Loop Result

## Bảng phân tích ảnh hưởng (Impact table)
| File | Hàm / Phương thức | Component / Service | Mức độ rủi ro (HIGH/MED/LOW) |
|------|-------------------|---------------------|------------------------------|

## Danh sách cần kiểm tra (Retest list)
- Component.method1 (Lý do chọn)
- Service.method2 (Lý do chọn)

## Kết quả Coverage
- Functions: X%
- Lines: Y%
- Branches: Z%

## Bằng chứng kiểm thử (Evidence)
- File báo cáo: coverage/<project-name>/index.html
- Nén bằng chứng: evidence/angular-loop-<n>.zip

## Nhật ký vòng lặp
- Vòng 1: Đạt X% nhánh. Thiếu: Nhánh if(data == null).
- Vòng 2: Đạt Y% nhánh. Thiếu: Nhánh catchError HTTP 500.
```

## Safety boundaries

- Không chỉnh sửa mã nguồn nghiệp vụ `src/app` trong quá trình chạy test loop.
- Không hạ thấp ngưỡng coverage yêu cầu (90%) trong cấu hình `angular.json` hoặc `karma.conf.js` trừ khi có lệnh.
- Không xóa các test case cũ để tăng coverage ảo.
- Không tự ý commit mã nguồn khi chưa được yêu cầu.