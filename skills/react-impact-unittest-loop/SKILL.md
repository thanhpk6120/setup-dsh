# React Impact Unit Test Loop

## 1. Impact
- Kiểm tra `git status` hoặc `git diff` để xác định các file React component, hook hoặc util bị thay đổi.
- Theo dõi log (nếu có) để xem luồng dữ liệu (trace) liên quan đến file bị sửa.

## 2. Target
- Xác định chính xác hàm, component thay đổi trực tiếp.
- Xác định các component/hook liền kề (parent/child/consumer) chịu ảnh hưởng từ thay đổi.

## 3. Tạo test
- Dùng **Vitest** (ưu tiên) hoặc **Jest** cùng `@testing-library/react`.
- Cấu trúc test cơ bản:
  - Mock external dependencies: `vi.fn()` hoặc `jest.fn()`.
  - Render component: `render(<MyComponent />)`.
  - Giả lập tương tác: `fireEvent.click()` hoặc `userEvent.click()`.
  - Bao phủ các nhánh (branches): 
    - Nhánh happy path (thành công).
    - Nhánh null/empty (không có dữ liệu).
    - Nhánh error (xử lý ngoại lệ, API fail).

## 4. Chạy selective
- Chạy test kèm coverage chỉ riêng cho các file/component bị ảnh hưởng để phản hồi nhanh:
  ```bash
  # Vitest
  npx vitest run src/components/MyComponent.test.tsx --coverage

  # Jest
  npx jest src/components/MyComponent.test.tsx --coverage
  ```

## 5. Loop-until-90
- Đọc báo cáo coverage từ terminal hoặc mở file `coverage/lcov-report/index.html`.
- Kiểm tra tỉ lệ bao phủ. Mục tiêu: **>= 90% Statement và Branch**.
- Nếu chưa đạt 90%:
  - Tìm dòng/nhánh báo đỏ (uncovered).
  - Bổ sung test case tương ứng cho dòng/nhánh đó.
  - Chạy lại bước 4.
- Lặp lại đến khi đạt mục tiêu 90%.

## 6. Stop-and-ask
- Sau khi hoàn thành loop và đạt 90% coverage, dừng lại và hỏi/báo cáo kết quả.
- Báo cáo: "Đã cover 90%+ cho component X, có cần test thêm edge case nào đặc biệt không?"
