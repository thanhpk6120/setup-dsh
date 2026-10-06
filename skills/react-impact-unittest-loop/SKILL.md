---
name: react-impact-unittest-loop
description: 'Phân tích vùng ảnh hưởng, tự động tạo test case Vitest/Jest và chạy lặp để đạt 90% coverage cho mã nguồn React.'
---

# React Impact Unittest Loop

Sử dụng skill này sau khi đã hoàn tất thay đổi mã nguồn React và người dùng yêu cầu kiểm tra lại (retest), đánh giá ảnh hưởng (impact), hoặc nâng cao độ phủ (coverage).

**Giới hạn của React Coverage**: Các công cụ React (`vitest` với `@vitest/coverage-v8` hoặc `@vitest/coverage-istanbul`, `jest` với `istanbul`/`c8`) không hỗ trợ sẵn việc tự động lọc coverage chỉ cho các hàm bị thay đổi (changed-methods). Do đó, phải kết hợp `git diff --name-only` để lấy danh sách file thay đổi và `git diff -U0` để lấy các dòng thay đổi, ánh xạ tới component/hook/function, chỉ chạy test chọn lọc (`vitest run`, `vitest related`, `jest` kèm `--collectCoverageFrom`) cho file bị đổi, rồi tự lọc file báo cáo `coverage/lcov.info` hoặc `coverage/coverage-final.json` để tính toán tỷ lệ bao phủ đúng cho hàm/dòng thay đổi. Báo cáo giữ nguyên định dạng mặc định (`coverage/index.html` và `coverage/lcov.info`), không dùng template custom.

## 1. Phân tích vùng ảnh hưởng (Impact)

Sử dụng `git status` hoặc `git diff --name-only` để phân loại các file React component, hook hoặc util đã thay đổi.
Nếu có GitNexus MCP, dùng lệnh `impact/context/trace` để quét đồ thị phụ thuộc.
Nếu không, phân tích thủ công theo thứ tự đọc: `router -> view/page -> component -> custom hook / context -> store/slice -> api service`.
Lập bảng đánh giá mức độ ảnh hưởng: File / Hàm / API tương ứng / Mức độ rủi ro (HIGH/MED/LOW).

## 2. Xác định mục tiêu cần kiểm tra (Target)

Chỉ định các hàm, component cụ thể cần viết test dựa trên quy tắc sau:
- Bao gồm các hàm/component bị thay đổi trực tiếp (dựa theo `git diff -U0` lấy danh sách file và dòng thay đổi, map tới function/component chứa dòng đó).
- Bao gồm các component/hook kế cận (parent/child/consumer) chịu ảnh hưởng từ thay đổi với khoảng cách 1 hop.
- Bao gồm các API handler hoặc custom hook liên quan trực tiếp đến luồng logic thay đổi.
- Loại trừ các đoạn mã được sinh tự động (generated code) hoặc các file cấu hình hệ thống (config).
- Nếu thiếu mục tiêu cần kiểm tra hoặc thiếu filter, phải dừng lại hỏi ý kiến người dùng trước khi tiến hành.

## 3. Tạo bài kiểm tra (Tạo test)

Viết các bài kiểm tra bằng Vitest (ưu tiên) hoặc Jest cùng `@testing-library/react` và `@testing-library/user-event`.
Đặt file test chung thư mục với component/hook hoặc trong `src/__tests__`. Tên file test phải có hậu tố `.test.tsx` hoặc `.spec.tsx` (ví dụ `MyComponent.test.tsx`).
Giả lập (mock) các đường ranh giới hệ thống như API HTTP, Web Storage (localStorage/sessionStorage), hoặc DOM API đặc biệt (ResizeObserver, IntersectionObserver).
Mỗi nhánh logic (branch) bị thay đổi phải có ít nhất một test case tương ứng:
- Đường dẫn chuẩn (happy path)
- Giá trị null hoặc dữ liệu trống (empty/undefined)
- Bắn lỗi (exception, API error 4xx/5xx)
- Trạng thái loading / pending
- Quyền truy cập (permission / role conditional render)

## 4. Chạy kiểm tra chọn lọc (Chạy selective)

Thực thi test riêng lẻ trên các file vừa tạo hoặc thay đổi, cấm chạy toàn bộ test suite trừ khi vùng ảnh hưởng lan rộng toàn hệ thống. Cần xác nhận với người dùng trước khi chạy toàn bộ suite hoặc nếu thiếu cờ filter.
Với Vitest:
```bash
# Chạy theo file test cụ thể kèm coverage
npx vitest run src/components/MyComponent.test.tsx --coverage

# Chạy test liên quan đến file source bị thay đổi
npx vitest related src/components/MyComponent.tsx --coverage
```
Với Jest:
```bash
# Chạy file test cụ thể và chỉ thu thập coverage trên file source bị ảnh hưởng
npx jest src/components/MyComponent.test.tsx --coverage --collectCoverageFrom="src/components/MyComponent.tsx"
```

## 5. Vòng lặp cải thiện độ phủ (Loop-until-90)

Sinh báo cáo bằng định dạng mặc định của công cụ test:
- Vitest: `coverage/index.html` (HTML), `coverage/lcov.info` (LCOV), `coverage/coverage-final.json` (JSON).
- Jest: `coverage/lcov-report/index.html` (HTML), `coverage/lcov.info` (LCOV), `coverage/coverage-final.json` (JSON).
Đọc file báo cáo `coverage/lcov.info` hoặc `coverage/coverage-final.json`. Sử dụng script để lọc và tính toán tỷ lệ bao phủ theo dòng (Line), nhánh (Branch), hàm (Function), lệnh (Statement) chỉ cho đúng các hàm/dòng đã thay đổi từ git diff.
Điều kiện đạt: Tỷ lệ lớn hơn 90% ở Statement và Branch đối với các hàm/dòng bị ảnh hưởng.
Nếu chưa đạt, chỉ sửa và bổ sung test case, sau đó chạy lại lệnh test selective và coverage.
Giới hạn tối đa 5 vòng lặp.
Ở mỗi vòng:
- Ghi nhật ký: Số thứ tự vòng lặp / Tỷ lệ coverage còn thiếu / Các nhánh (branch) chưa được phủ.
- Mở file HTML coverage report (`coverage/index.html`) cho người dùng xem nếu cần bằng lệnh OS (start/open) hoặc `npx serve coverage`.
- Đóng gói bằng chứng (evidence): Nén thư mục `coverage/` và test logs thành file `evidence/react-loop-<vong>.zip` (ví dụ `evidence/react-loop-1.zip`).

## 6. Dừng và xin ý kiến (Stop-and-ask)

Dừng vòng lặp và hỏi người dùng nếu thỏa mãn một trong các điều kiện dừng thật:
- Phát hiện lỗi logic nghiệp vụ nghiêm trọng có thể ảnh hưởng production.
- Mã nguồn không thể viết test (untestable code) do thiết kế (ví dụ component/hook quá phức tạp, tightly coupled không thể mock dependency).
- Coverage không tăng trong 2 vòng lặp liên tiếp hoặc chạm mốc 3-5 iterations mà không đạt 90%.
Khi dừng, trình bày rõ câu hỏi cùng với bằng chứng cụ thể từ logs hoặc code.

## Output

```markdown
# React Impact Test Loop Result

## Bảng phân tích ảnh hưởng (Impact table)
| File | Hàm/Component | API | Mức độ rủi ro (HIGH/MED/LOW) |
|------|---------------|-----|------------------------------|

## Danh sách cần kiểm tra (Retest list)
- MyComponent.handleAction (Lý do chọn)
- useDataHook.fetchData (Lý do chọn)

## Kết quả Coverage (Vitest/Jest, chỉ hàm liên quan git)
- STATEMENT: X%
- LINE: Y%
- BRANCH: Z%
- FUNCTION: W%

## Nhật ký vòng lặp
- Vòng 1: Đạt X% nhánh. Thiếu: Nhánh kiểm tra dữ liệu rỗng. Evidence: evidence/react-loop-1.zip
- Vòng 2: Đạt Y% nhánh. Thiếu: Nhánh xử lý API error. Evidence: evidence/react-loop-2.zip
```

## Safety boundaries

- Không chỉnh sửa mã nguồn gốc (`src/`) trong quá trình chạy test loop chỉ để dễ test nếu chưa có yêu cầu từ người dùng.
- Không hạ thấp ngưỡng coverage yêu cầu (90%).
- Không xóa các test case cũ chỉ để làm tăng tỷ lệ coverage ảo.
- Không tự ý chạy toàn bộ test suite mà không hỏi ý kiến người dùng khi chưa có filter cụ thể.
- Không tự ý commit hoặc push mã nguồn khi chưa có yêu cầu từ người dùng.
