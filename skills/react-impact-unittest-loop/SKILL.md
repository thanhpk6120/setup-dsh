---
name: react-impact-unittest-loop
description: 'Phân tích vùng ảnh hưởng, tự động tạo test case Vitest/Jest và chạy lặp để đạt ít nhất 90% coverage cho phần code React đã thay đổi.'
---

# React Impact Unittest Loop

Sử dụng skill này sau khi mã nguồn React thay đổi, để đánh giá ảnh hưởng (impact), viết test, và đảm bảo những đoạn code mới/sửa đổi đạt tối thiểu 90% coverage.

**Lưu ý quan trọng**: Vitest/Jest không tự lọc coverage theo dòng code bị sửa. Bạn phải lấy danh sách dòng bị sửa bằng git, chạy test file tương ứng, và trích xuất chỉ số coverage cho đúng các dòng đó từ file lcov/json báo cáo mặc định.

## Workflow tự nhiên

### 1. Đánh giá ảnh hưởng (Impact)
- Chạy `git diff -U0` hoặc `git diff --name-only` để biết file nào đổi, dòng nào đổi.
- Ánh xạ các dòng đổi tới các component, hook hoặc function tương ứng.
- Xác định phạm vi ảnh hưởng (các component cha/con gần nhất, API call).
- Nếu thay đổi quá phức tạp hoặc chưa rõ vùng cần test, dừng lại để hỏi người dùng.

### 2. Viết Test & Mock (Vitest/Jest)
- Tạo hoặc cập nhật file test cạnh component/hook (ví dụ `.test.tsx`).
- Mock các biên (boundaries) như API, DOM API, thư viện ngoài bằng `vi.fn()`, `vi.spyOn()`, hoặc `vi.mock()`. (Với Jest, dùng `jest.fn/mock/spyOn`).
- Phủ các nhánh của logic thay đổi: Happy path, empty/null data, loading, và error.

### 3. Chạy Selective & Đọc Coverage
- Chạy test **chỉ cho file bị thay đổi** để nhanh và cô lập:
  - Vitest: `vitest run <file.test.tsx> --coverage` hoặc `vitest related <file.tsx> --coverage`
  - Jest: `jest <file.test.tsx> --coverage --collectCoverageFrom="<file.tsx>"`
- Đọc file báo cáo mặc định sinh ra (ví dụ `coverage/lcov.info` hoặc `coverage/coverage-final.json`).
- Áp dụng bộ lọc (script) trên file lcov để tính toán tỷ lệ Statement/Branch coverage của riêng **các hàm/dòng bị thay đổi**.

### 4. Vòng lặp tối ưu 90% (Loop)
- Nếu coverage của phần code đổi chưa đạt 90% (Statement và Branch), tiếp tục bổ sung test case.
- Giới hạn tối đa **5 vòng lặp**.
- Mỗi vòng, nếu cần, có thể mở file báo cáo HTML (bằng lệnh OS hoặc `npx serve coverage`) để phân tích nguyên nhân thiếu.

### 5. Hoàn thành / Dừng và Hỏi (Stop-and-ask)
- Nén bằng chứng (coverage, log) **một lần duy nhất** vào file `evidence/react-final-coverage.zip` khi thành công đạt 90% hoặc buộc phải dừng ở cuối quy trình.
- Nếu kẹt (không thể test do component quá phức tạp / tightly coupled), hoặc coverage không tăng 2 vòng liên tiếp.
- Nếu phát hiện code bị lỗi logic.
- Dừng ngay và báo cáo/hỏi ý kiến người dùng, gửi kèm file bằng chứng.
## Output Template

Báo cáo kết quả theo format sau:

```markdown
# React Impact Test Loop Result

## 1. Vùng ảnh hưởng (Impact)
- File thay đổi: `src/components/MyComponent.tsx`
- Hàm/Component: `handleSubmit`
- Mức độ rủi ro: MED

## 2. Các thay đổi Test
- Đã thêm file: `MyComponent.test.tsx`
- Các case phủ: Happy path, Network Error.

## 3. Kết quả Coverage (Chỉ tính trên hàm/dòng thay đổi)
- STATEMENT: X%
- LINE: Y%
- BRANCH: Z%
- FUNCTION: W%

## 4. Nhật ký vòng lặp
- Vòng 1: Đạt 70% branch. Thiếu: Nhánh báo lỗi API.
- Vòng 2: Đạt 95% branch. Đã phủ toàn bộ.

## 5. Bằng chứng
- File: `evidence/react-final-coverage.zip`
```


## Safety Boundaries (Luật an toàn)

- **Cấm sửa mã nguồn (src/)** chỉ để code dễ test hơn khi chưa xin phép người dùng.
- **Cấm hạ threshold (90%)** yêu cầu đối với phần code thay đổi.
- **Cấm xóa test cũ** để làm đẹp hoặc thao túng tỷ lệ coverage.
- **Cấm chạy full test suite** nếu không có yêu cầu từ người dùng (làm tốn thời gian, rác log).