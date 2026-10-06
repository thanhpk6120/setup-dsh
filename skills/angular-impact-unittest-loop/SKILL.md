# Angular Impact Unittest Loop

# Mục tiêu
Skill này hướng dẫn quy trình tạo và chạy unit test cho dự án Angular bằng Jasmine + Karma, hướng tới mục tiêu tối thiểu 90% coverage cho phần mã nguồn bị ảnh hưởng.

# Quy trình (6 phases)

## Phase 1: Impact (Phân tích ảnh hưởng)
- Xác định rõ component, service, pipe, hoặc directive nào cần được test.
- Phân tích sự phụ thuộc (dependencies): nó inject những service nào, component con là gì.
- Liệt kê các kịch bản test (happy path, error cases, edge cases).

## Phase 2: Target (Xác định mục tiêu)
- Tìm file test tương ứng (`*.spec.ts`). Nếu chưa có, tạo mới.
- Gom nhóm các kịch bản theo hành vi (describe, it).
- Nhắm mục tiêu coverage: Statements, Branches, Functions, Lines phải đạt tối thiểu 90% cho file bị ảnh hưởng.

## Phase 3: Create Test (Tạo test)
- **Setup TestBed**: Khai báo `TestBed.configureTestingModule` với các module, component, providers cần thiết.
- **Mock Service**: Dùng `jasmine.createSpyObj('ServiceName', ['methodName'])` để tạo mock service, tránh gọi đến service thật. Dùng `mockService.methodName.and.returnValue(...)` để giả lập kết quả.
- **Branch/Happy/Error**: Viết test cover đầy đủ:
  - Happy path: Chức năng chính hoạt động như mong đợi.
  - Branching: Các trường hợp rẽ nhánh (if/else, switch/case).
  - Error: Xử lý lỗi (error từ API, dữ liệu đầu vào sai).

## Phase 4: Chạy test chọn lọc (Selective Run)
- Chỉ chạy test cho file đang làm việc thay vì toàn bộ dự án để tiết kiệm thời gian.
- Lệnh: `ng test --include=src/app/path/to/file.spec.ts --no-watch --code-coverage`

## Phase 5: Loop-until-90
- Mở file report coverage (`coverage/lcov-report/index.html` hoặc xem trực tiếp log terminal).
- Nếu coverage dưới 90%, xác định những dòng code/nhánh chưa được cover.
- Bổ sung thêm test case.
- Lặp lại Phase 4 và 5 cho đến khi đạt >= 90%.

## Phase 6: Stop-and-ask
- Nếu bị kẹt (test mãi không pass, mock quá phức tạp, coverage không lên), dừng lại và phân tích kĩ hơn, hoặc đặt câu hỏi với người có kinh nghiệm/reviewer. Không cố gắng hack coverage bằng cách test vô nghĩa.
