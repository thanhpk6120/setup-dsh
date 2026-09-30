---
name: init-docs
description: Use when the user asks to initialize, regenerate, refresh, audit, or update project map docs such as architecture.md, specs/*.md, design.md, or run the Spec-Driven init docs workflow.
---

# Rule 00 — Init Docs

**Goal:** Khởi tạo lần đầu hoặc đồng bộ lại tài liệu nguồn của dự án (`ARCHITECTURE.md`, `specs/*.md`, `DESIGN.md`, `COMMANDS.md`) từ source code và `AGENTS.md` của các service.

**Khi nào chạy:**
- Khi docs repo vừa được clone về và chưa có `ARCHITECTURE.md` chuẩn.
- Sau khi thêm service mới vào workspace.
- Sau refactor lớn làm thay đổi kiến trúc tổng thể.

**Input:**
- Toàn bộ source code các service repo ngang hàng.
- `AGENTS.md` của từng service repo (nếu có).
- Project root `AGENTS.md`.

**Output:**
- `docs/ARCHITECTURE.md` — kiến trúc tổng thể.
- `docs/DESIGN.md` — thiết kế UI/UX.
- `docs/COMMANDS.md` — catalog lệnh thao tác nhanh cho dev/CI.
- `docs/specs/<domain>.md` — đặc tả nghiệp vụ theo từng domain.

### Quy ước đặt tên file (Naming Convention)
- **Tài liệu cấp 1 (Root docs trong `docs/`):** Bắt buộc đặt tên **CHỮ HOA** (`README.md`, `ARCHITECTURE.md`, `DESIGN.md`, `COMMANDS.md`, `AGENTS-TEMPLATE.md`).
- **Tài liệu cấp 2 (Domain specs, Rules, Features):** Bắt buộc đặt tên **chữ thường kebab-case** (`docs/specs/<domain-name>.md`, `docs/rules/<rule-name>.md`, `expect.md`, `plan.md`, `tasks.md`, `report.md`, `deploy.md`).

---

> **Multi-Agent Orchestration Contract:** Phiên chính đóng vai trò Dispatcher/Control. Bắt buộc sử dụng tool `task` gọi agent `docs-init` (hoặc `docs-update`) để phân tích toàn hệ thống và soạn tài liệu, chia slice theo service/module khi khảo sát nhiều phần. Sau đó gọi `docs-reviewer` đánh giá chất lượng trước khi gửi người dùng duyệt.

## Quy tắc Bảo toàn Tài liệu (MANDATORY INVARIANT)
> **TUYỆT ĐỐI KHÔNG XÓA (ADDITIVE-ONLY):** Khi tài liệu (các file trong `docs/`) đã tồn tại, **NGHIÊM CẤM** xóa bỏ, ghi đè trắng (overwrite/regenerate) toàn bộ file làm mất các phần (section), đoạn văn, hoặc ghi chú đã có. 
> - CHỈ được phép **bổ sung thêm** thông tin mới (append/additive update) hoặc điều chỉnh nội dung cũ nếu thực sự sai lệch so với code thực tế.
> - Mọi nội dung cũ do con người viết (context, business rules, giải thích ngoại lệ) phải được giữ nguyên vẹn.
> - Phải dùng thao tác chỉnh sửa từng phần (patch/diff) thay vì đè nội dung mới hoàn toàn lên file cũ.

## Quy trình

### 0. Bắt buộc trước khi viết
- Bắt đầu mọi phiên bằng `git pull` trong `docs/`.
- Trong lần đọc instruction đầu tiên, đọc **chỉ một file instruction** theo thứ tự ưu tiên:
  1. Nếu có `CLAUDE.md` ở workspace root: đọc `CLAUDE.md` và **không đọc `AGENTS.md`**.
  2. Nếu không có `CLAUDE.md` nhưng có `AGENTS.md`: đọc `AGENTS.md`.
  3. Nếu không có cả hai: tiếp tục với `README.md` và báo thiếu file instruction.
- File instruction được chọn dùng để biết:
  - role của workspace,
  - quy ước project đã được chuẩn hóa,
  - phần docs nào được phép tự cập nhật, phần nào cần diff/PR.
- Nếu file instruction được chọn cấm sinh/cập nhật file nào, dừng và báo người dùng.

### 1. Khảo sát kiến trúc
- Lập sơ đồ service: tên repo, trách nhiệm chính, loại ứng dụng (web/api/worker/...), công nghệ.
- Xác định cách các service giao tiếp: HTTP, message queue, gRPC, sự kiện, file shared...
- Ghi rõ điểm vào/ra ngoài hệ thống: auth provider, DB ngoài, CDN, gateway...
- Nếu service repo có GitNexus index, dùng `mcp__gitnexus__query` để tìm các execution flow chính, `mcp__gitnexus__context` trên các symbol trung tâm để xác nhận trách nhiệm, `mcp__gitnexus__route_map` để liệt kê API/handler đã biết, `mcp__gitnexus__cypher` chỉ khi cần truy vấn đồ thị nâng cao. Nếu `gitnexus://repo/<name>/context` báo index stale, báo người dùng và dừng, không suy diễn.

### 2. Quyết định có cần sinh/cập nhật bản đồ dự án
- Bản đồ dự án gồm: `docs/ARCHITECTURE.md`, `docs/specs/*.md`, `docs/DESIGN.md`.
- Nếu đọc source/docs và thấy các file bản đồ đã đủ, còn đúng, không cần sinh/cập nhật: **không hỏi**, chỉ báo không cần thay đổi.
- Nếu cần sinh mới hoặc cập nhật bất kỳ file bản đồ nào: **bắt buộc hỏi người dùng trước khi ghi file**.
- Câu hỏi phải nêu rõ:
  - file nào sẽ được sinh/cập nhật,
  - lý do cần thay đổi,
  - nguồn thông tin đã dùng,
  - rủi ro nếu docs sai.
- Chỉ ghi file sau khi người dùng đồng ý rõ ràng.

### 3. Sinh/cập nhật `ARCHITECTURE.md`
- Cấu trúc tối thiểu:
  - Tổng quan hệ thống (1 đoạn).
  - Danh sách service + trách nhiệm 1 dòng mỗi service.
  - Sơ đồ giao tiếp dạng text (không bắt buộc hình).
  - Stack mỗi service (đã xác nhận từ source, không bịa).
  - Cơ chế triển khai/thư mục vận hành nếu đọc được từ repo (ví dụ `docker-compose.yml`, `Dockerfile`, script trong `bundles/`).
- Ghi rõ phần nào đã xác nhận, phần nào còn giả định.

### 4. Sinh/cập nhật `specs/<domain>.md`
- 1 domain = 1 file. Domain phân theo nghiệp vụ, không phân theo service.
- Mỗi file gồm:
  - mục tiêu domain,
  - luồng chính (happy path),
  - luồng phụ / exception,
  - actor chính (user role nào).
- Không tự ý tách domain khi chưa có dấu hiệu rõ từ code; khi mơ hồ, hỏi trước khi ghi.

### 5. Sinh/cập nhật `DESIGN.md`
- Mô tả UI/UX hiện tại theo quan sát thật từ service.
- Liệt kê các màn hình/portlet/component chính; tránh liệt kê mọi chi tiết nhỏ.

### 6. Câu hỏi mở
- Sau khi sinh xong, gom lại phần thắc mắc vào mục "Câu hỏi mở" để BA/TechLead giải đáp trước khi dùng docs cho plan.

---

## Tiêu chí dừng (gate)
- AI **không** code, không mở PR đến service repo.
- Nếu thiếu thông tin để xác nhận một phần, phải ghi "chưa xác nhận" kèm lý do thay vì tự đoán.
- Mọi thay đổi đều được đề xuất dạng diff và chờ TechLead approve (Gate 2 trong `README.md`).
- **Bảo toàn dữ liệu:** Phải đảm bảo không làm mất hoặc xóa lầm bất kỳ nội dung cũ nào trong quá trình cập nhật tài liệu.
