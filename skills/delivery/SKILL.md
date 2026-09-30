---
name: delivery
description: Quy trình delivery 2 cổng kết hợp Dely protocol và rule create-plan trong OMP. Điều phối implementer và reviewer độc lập trong cùng phiên.
---

# Delivery Protocol (OMP Native Subagents)

Quy trình áp dụng triết lý phân tách vai trò của Dely protocol, tích hợp trực tiếp vào OMP thông qua Subagents và quy chuẩn tài liệu của `setup-global`.

## Nguyên tắc cốt lõi

1. **Phiên chính là Control**: Chỉ lập kế hoạch, hỏi ý kiến/lấy duyệt người dùng, điều phối subagent và kiểm tra trạng thái. **Không trực tiếp sửa source code, không tự review code**.
2. **Khai thác Subagents chuyên biệt**:
   - `dely-implementer`: Sử dụng `claude-sonnet-5:medium` chuyên code theo TDD.
   - `dely-reviewer`: Sử dụng `claude-opus-5:high` chuyên review độc lập, tự chạy lại verification.
3. **Quy tắc Git an toàn**:
   - Bắt đầu: Có thể chạy `git pull` để đồng bộ code mới nhất trước khi làm việc.
   - **Tuyệt đối KHÔNG tự động `git merge` hay tạo PR** khi chưa có yêu cầu cụ thể từ người dùng.

---

## Các bước thực hiện

### Bước 1: Đồng bộ & Khởi tạo (Context Refresh)
- Chạy `git pull` trên repository liên quan để cập nhật code mới nhất.
- Đọc yêu cầu thay đổi / tính năng.

### Bước 2: Viết Design Contract / Spec (Gate 1)
- Áp dụng skill `create-plan` và tuân thủ chặt chẽ rule `create-plan.md`.
- Vị trí tài liệu: `docs/features/<feature-name>/` (hoặc `docs/feature/<feature-name>/`, ưu tiên cấu trúc thư mục sẵn có của dự án):
  - `plan.md`: Bao gồm Architecture, Scope, Bảng Acceptance Criteria kết hợp Counterexamples.
  - `tasks.md`: Danh sách tasks được chia nhỏ, có DoD và lệnh kiểm thử rõ ràng.
- **Bảng Acceptance & Counterexamples**:
  Mỗi tiêu chí trong `plan.md` bắt buộc phải có counterexample:
  | Requirement | Instrument | Counterexample | Observed Red |
  | --- | --- | --- | --- |
  | Yêu cầu X | Lệnh test Y | Logic sai Z mà test Y vẫn phải bắt được | Chờ implementer điền |
- **Dừng lại xin duyệt (Gate 1)**:
  Dùng tool `ask` trình bày tóm tắt plan và xin duyệt từ người dùng. **Chưa được duyệt tuyệt đối không gọi implementer code.**

### Bước 3: Triển khai Task (Implementation Phase)
- Sau khi Gate 1 được duyệt, Control gọi tool `task`:
  - Chọn agent: `dely-implementer`.
  - Có thể truyền mảng `tasks[]` với nhiều task độc lập để chạy song song.
  - Giao task kèm theo: phạm vi file được sửa, yêu cầu test, và bảng counterexample.
- Chờ nhận kết quả từ implementer với khối bắt buộc:
  `END OF HANDOFF`

### Bước 4: Đánh giá độc lập (Review Phase)
- Sau khi implementer hoàn tất, Control gọi tool `task` spawn:
  - Chọn agent: `dely-reviewer`.
  - Truyền ngữ cảnh: `git diff`, `plan.md`, `tasks.md`.
- Reviewer sẽ tự chạy lại các lệnh test/gate, kiểm tra counterexample, và trả về:
  - `ACCEPT`: Chuyển sang bước tiếp theo.
  - `CHANGES_REQUESTED`: Control điều phối lại cho `dely-implementer` sửa lỗi. Nếu lặp lại CHANGES_REQUESTED quá 2 lần cho cùng một lỗi → ESCALATE: dừng lại, lập báo cáo bất đồng và xin ý kiến quyết định từ người dùng.

### Bước 5: Báo cáo hoàn tất (Gate 2)
- Thông báo cho người dùng kết quả triển khai và review.
- Trình bày tóm tắt các file đã thay đổi và kết quả test.
- Chờ chỉ thị tiếp theo từ người dùng (nếu người dùng yêu cầu tạo PR hoặc merge thì mới thực hiện).
