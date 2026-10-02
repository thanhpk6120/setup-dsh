---
name: reload-context
description: Use when the user says compact xong, mất context, nạp lại instruction, restore session, or after context compaction, session reset, /clear, or starting a new session in an existing workspace to reload and verify instructions and project state.
---

# Reload Context

**Goal:** Khôi phục toàn bộ ngữ cảnh vận hành (system instructions, global rules, project architecture, skills index, runtime config và git state) ngay lập tức sau khi session bị compact, mất context, clear session, hoặc mở phiên làm việc mới trên workspace hiện tại.

**Khi nào chạy:**
- Ngay sau khi compaction tự động diễn ra (`compact xong`, `snapcompact`).
- Khi user thông báo agent bị quên ngữ cảnh, hallucinate hoặc `mất context`.
- Khi user yêu cầu `nạp lại instruction` hoặc `restore session`.
- Ngay khi bắt đầu một phiên làm việc mới trong workspace đã có sẵn tài liệu/source code.

**Input:**
- Project root instructions: `AGENTS.md`, `RULES.md`.
- Project template / role (nếu có): `SYSTEM.md`.
- Skills catalog: danh mục `skills/*/SKILL.md`.
- Runtime configuration:
  - OMP: `~/.omp/agent/config.json`, `~/.omp/agent/mcp.json`, `bootstrap.ps1`.
  - DSH: `~/.dsh/`, `cordis.patch.yml`.
- Working tree state: kết quả từ `git status` và `git diff --stat`.

**Output:**
- Checklist xác nhận các thành phần ngữ cảnh đã được nạp thành công.
- Tóm tắt ngắn gọn trạng thái hiện tại (Branch, Dirty files, Active tickets/tasks nếu có).
- Ready state để tiếp tục nhận lệnh mà không vi phạm quy tắc.

---

## 1. Nguồn chân lý (Source of Truth Hierarchy)

Khi nạp lại ngữ cảnh, agent phải tuân thủ thứ tự ưu tiên của các nguồn tài liệu:

1. **`RULES.md`**: Global hard rules, Precedence rule, Pre-flight prefix requirement, MCP routing, quy tắc bảo toàn dữ liệu (Recycle Bin / Trash).
2. **`AGENTS.md`**: Project overview, Service registry, Layer read order, Tech stack, Task classification tier (1/2/3), Delegation logic, Quick rules.
3. **`SYSTEM.md`** (nếu có): Project guide template hoặc root specification khi dự án chưa hoàn thiện `AGENTS.md`.
4. **`docs/ARCHITECTURE.md` & `docs/specs/*.md`** (nếu có docs repo): Bản đồ kiến trúc dịch vụ và đặc tả nghiệp vụ chi tiết.
5. **`skills/*/SKILL.md`**: Index các kỹ năng chuyên biệt đã đăng ký trong workspace.
6. **Runtime config (`bootstrap.ps1`, `mcp.json`)**: Công cụ MCP và model roles đang hoạt động.
7. **`git status`**: Thực tế working tree tại thời điểm hiện tại.

---

## 2. Quy trình nạp lại ngữ cảnh (Reload Procedure)

Thực hiện tuần tự theo 6 bước bắt buộc:

### Bước 1: Nạp Core Instructions (`AGENTS.md`)
- Đọc `AGENTS.md` tại workspace root.
- Xác định:
  - Project overview & mục tiêu dự án.
  - Quy ước Pre-flight assessment & Task tiering (Tier 1 Direct, Tier 2 Single Subagent, Tier 3 Parallel Subagents).
  - Service registry table và layer read order (`{{LAYER_READ_ORDER}}`).
  - Danh mục lệnh verify (`{{VERIFY_COMMANDS}}`).

### Bước 2: Nạp Global Rules (`RULES.md`)
- Đọc `RULES.md` tại workspace root.
- Ghi nhận các bất biến bắt buộc (Mandatory Invariants):
  - Prefix `[Pre-flight] Tier: ... | Skills: ... | Plugins/MCP: ... | Rationale: ... | Action: ...` trước mọi tool call.
  - Precedence: Delegation & MCP override tính Simplicity và Think Before Coding.
  - Tuyệt đối không xóa file vĩnh viễn (phải dùng Recycle Bin / Trash).
  - Trả lời bằng tiếng Việt (trừ code, commands, IDs).
  - Không tự ý commit/push/merge trừ khi được yêu cầu rõ ràng.

### Bước 3: Kiểm tra `SYSTEM.md` (nếu tồn tại)
- Kiểm tra xem file `SYSTEM.md` có ở workspace root hay không.
- Nếu tồn tại và có thông tin dự án chưa chuyển đổi vào `AGENTS.md`, đọc để nắm bổ sung context; nếu là template dạng `{{PLACEHOLDER}}`, ghi nhận trạng thái template.

### Bước 4: Nạp Skills Index
- Quét nhanh danh mục `skills/` (hoặc `docs/skills/` nếu theo cấu trúc docs repo).
- Nắm danh sách các skill khả dụng (ví dụ: `reload-context`, `init-docs`, `implement-task`, `create-plan`, `security-review`, `delivery`, `poka-yoke`...) để kích hoạt đúng khi có task tương ứng.

### Bước 5: Nạp Runtime Config & MCP
- Kiểm tra file cấu hình bootstrap và MCP:
  - Đọc `bootstrap.ps1` (nếu có trong repo) hoặc runtime config để nắm các MCP servers đang được thiết lập (`memorix`, `gitnexus`, `company-atlassian`, `context7`, `cloakbrowser`).
  - Ghi nhận directive `snapcompact.systemPrompt: agents-md,rules-md` để hiểu cơ chế giữ context nền của agent runtime.

### Bước 6: Quét nhanh Git Status & Diff
- Chạy `git status --short` và `git diff --stat`.
- Xác định:
  - Branch hiện tại.
  - Các thay đổi dở dang (staged / unstaged).
  - Nguy cơ dirty working tree để cảnh báo trước khi thực hiện task tiếp theo.

---

## 3. Adapters: OMP vs DSH

Tùy thuộc vào môi trường runtime đang chạy, agent áp dụng adapter tương ứng:

| Tiêu chí | OMP (Oh My Prompt) | DSH (Dev Shell / Cordis) |
|---|---|---|
| **Config Directory** | `~/.omp/agent/` (`$env:USERPROFILE\.omp\agent` trên Windows) | `~/.dsh/` |
| **Config Files** | `config.json`, `mcp.json`, `models.json` | `cordis.patch.yml`, cấu hình nội bộ DSH |
| **Snapcompact Hook** | `snapcompact.systemPrompt: agents-md,rules-md` tự động đưa `AGENTS.md` và `RULES.md` vào system prompt sau compact | Quản lý qua context buffer hoặc file override riêng trong cordis |
| **Plugin / Extensions** | `~/.omp/agent/extensions/` (vd: `memorix.js` cài qua `memorix setup --agent omp --global`) | Được tiêm qua layer container hoặc mount volume của Cordis sandbox |
| **MCP Definition** | Khai báo trong `~/.omp/agent/mcp.json` theo chuẩn Desktop MCP JSON | Khai báo qua `cordis.patch.yml` hoặc profile server của DSH |

---

## 4. Checklist xác nhận sau khi nạp (Output Checklist)

Sau khi hoàn tất quy trình, agent xuất báo cáo ngắn gọn xác nhận trạng thái:

```markdown
### [Context Reloaded]
- [x] AGENTS.md: Đã nạp (Tiering, Service Registry, Read Order)
- [x] RULES.md: Đã nạp (Pre-flight Prefix, Invariants, Trash rule)
- [x] SYSTEM.md: Đã kiểm tra (Đã nạp / Không có / Dạng template)
- [x] Skills Catalog: Đã index (Số lượng skills sẵn sàng)
- [x] Runtime & MCP: Xác nhận OMP / DSH adapter + MCP tools hoạt động
- [x] Git Working Tree: Branch `<branch-name>` | Status: `<clean | dirty (số files)>`

Trạng thái: Sẵn sàng nhận lệnh tiếp theo.
```
