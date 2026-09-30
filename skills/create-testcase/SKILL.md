---
name: create-testcase
description: Use when the user asks to create, draft, review, or update testcase.md for a docs/features ticket from expect.md, acceptance criteria, or the Spec-Driven workflow.
---

# Rule 03 — Create Testcase

> **Audience:** AI agent. Follow the steps in order. Do not skip a step and do not invent a step.
> **Goal:** Tạo `testcase.md` từ `expect.md` để kiểm chứng feature theo acceptance criteria, trước hoặc song song với implement.
> **Scope of this file:** this rule is **project-agnostic**. It must work unchanged for every project in the company.
> **Predecessor:** `docs/features/<TICKET-ID>/expect.md` (or `docs/rules/create-plan.md`).

---

## 0. Project configuration contract [READ THIS FIRST]

This rule contains **no project-specific hardcoded values**. All project configuration is defined in a single source of truth:

| File | What it provides |
|---|---|
| `{{PROJECT_ROOT}}/AGENTS.md` | Project overview, **service registry** (§4), tech stack (§5), quick rules & read order & verify commands (§10), agent working rules & integration surfaces (§11), git rules (§13), do-not-touch list (§14) |

### Configuration keys resolved directly from `AGENTS.md`

The rule references these by name. Each `{{key}}` used in this file resolves from `AGENTS.md`:

| Key | Location in `AGENTS.md` | Meaning |
|---|---|---|
| `{{SERVICE_TAGS}}` | §4.1 | Canonical service tag list, used when a test case must name the service under test |
| `{{IMPACT_TOOL}}` | §11.1 | Code-index / impact tool used to discover regression flows (`none` if unused) |
| `{{STATUS_VOCABULARY}}` | §11.1 | Allowed status values, used to mark a test case `blocked` or `draft` |
| `{{EXTRA_RULES}}` | §9 | Companion rules to read when relevant (`init-docs`, `create-plan`, `implement-task`) |

---

## 1. Khi nào chạy

- Sau khi BA đã có `docs/features/<TICKET-ID>/expect.md`.
- Nên chạy sau `create-plan.md` để tham chiếu plan, nhưng testcase vẫn phải bám `expect.md` làm nguồn chính.

## 2. Tiêu chí dừng — kiểm tra trước khi viết bất cứ gì

DỪNG và hỏi người dùng nếu một trong các điều sau đúng:

1. `docs/features/<TICKET-ID>/expect.md` không tồn tại.
2. `expect.md` thiếu acceptance criteria hoặc thiếu actor chính.
3. Không thể xác định expected result cho một acceptance criteria nào đó — ghi vào `Open Questions`, không tự đoán.

---

## 3. Inputs và outputs

### Inputs

| Input | Source | Required |
|---|---|---|
| `docs/features/<TICKET-ID>/expect.md` | BA | **Yes** — nguồn chính |
| `docs/features/<TICKET-ID>/plan.md` | Rule 01 | Nếu đã có — tham chiếu phạm vi kỹ thuật |
| `docs/specs/<domain>.md` | docs | **Yes** cho mọi domain liên quan |
| `docs/DESIGN.md` | docs | Khi feature có UI |
| `{{EXTRA_RULES}}` | docs | Khi điều kiện kích hoạt của rule đó áp dụng |

### Outputs

| Output | Description |
|---|---|
| `docs/features/<TICKET-ID>/testcase.md` | Bộ test case bám acceptance criteria, theo template ở Step 2 |

> **Output location is mandatory.** File phải được ghi trong `docs/features/<TICKET-ID>/` ở docs repo. Nếu thiếu quyền ghi vào đúng path đó, **hỏi xin quyền** — không ghi sang chỗ khác.

---

## 4. Quy trình

### Step 0 — Bắt buộc trước khi viết testcase

- Chạy `git pull` trong `docs/`.
- Đọc `expect.md` trước.
- Chỉ dùng `plan.md` để hiểu phạm vi kỹ thuật; không tạo testcase cho chi tiết implementation nếu không có trong acceptance criteria.

Nếu `expect.md` thiếu acceptance criteria hoặc actor chính:
- Dừng lại và hỏi BA/DEV.

### Step 1 — Trích xuất yêu cầu kiểm thử

Từ `expect.md`, xác định:
- actor/user role,
- precondition,
- input chính,
- hành động người dùng hoặc API call,
- expected result,
- out-of-scope không cần test,
- dữ liệu đặc biệt cần chuẩn bị.

Nếu `{{IMPACT_TOOL}}` không phải `none` và có index cho service liên quan, dùng nó để tìm regression flows. Với GitNexus: `mcp__gitnexus__query` để tìm execution flow liên quan, `mcp__gitnexus__context` trên symbol/API chính để biết callers/callees, và `mcp__gitnexus__route_map` khi testcase cần xác định API handler/consumer. Dùng kết quả này để bổ sung regression flows cần kiểm thử, không dùng để thay thế Acceptance Criteria trong `expect.md`.

### Step 2 — Viết testcase theo hành vi

Cấu trúc tối thiểu:

```md
# <TICKET-ID> — Testcase

## Scope

## Test Data

## Test Cases

| ID | Scenario | Preconditions | Steps | Expected Result | Priority |
|---|---|---|---|---|---|

## Non-Functional Checks

## Out of Scope

## Open Questions
```

Quy tắc:
- Mỗi acceptance criteria phải có ít nhất một testcase.
- Testcase phải mô tả hành vi quan sát được, không mô tả tên hàm/class nội bộ.
- UI testcase phải có bước người dùng rõ ràng.
- API testcase phải có request/response kỳ vọng ở mức business, không cần bịa endpoint nếu plan/docs chưa xác định.

### Step 3 — Bao phủ luồng lỗi và biên

Tạo testcase cho:
- happy path,
- input thiếu/sai,
- quyền không đủ nếu feature có phân quyền,
- dữ liệu rỗng,
- trạng thái đã tồn tại/trùng lặp nếu nghiệp vụ có khả năng đó.

Không tạo testcase giả cho tình huống không có trong scope.

### Step 4 — Liên kết testcase với acceptance criteria

- Nếu `expect.md` có mã AC, dùng mã đó trong testcase.
- Nếu không có mã AC, đánh số `AC1`, `AC2`, ... theo thứ tự trong `expect.md` và ghi rõ mapping.

Ví dụ:

```md
## Acceptance Criteria Mapping

| AC | Test Cases |
|---|---|
| AC1 | TC-001, TC-002 |
```

### Step 5 — Câu hỏi mở

Nếu không thể xác định expected result:
- Không tự đoán.
- Ghi vào `Open Questions`.
- Đánh dấu testcase liên quan là `blocked` hoặc `draft` theo `{{STATUS_VOCABULARY}}`.

---

## 5. Tiêu chí dừng

- Dừng sau khi tạo `docs/features/<TICKET-ID>/testcase.md`.
- Không code trong rule này.
- Không sửa `plan.md` trừ khi DEV yêu cầu rõ.
- Không tự claim testcase hoàn chỉnh nếu còn `Open Questions` ảnh hưởng acceptance criteria.

> `testcase.md` được Rule 02 (`implement-task.md`) đọc ở Step 4 và kiểm chứng ở Step 8. Mọi test case trong scope phải pass, hoặc được ghi rõ lý do trong `report.md`, trước khi đề xuất docs diff cho Gate 2.

---

## 6. Project customization

All project configurations live in:

👉 **`AGENTS.md`** at the project root (service registry, tech stack, quick rules, agent working rules, git rules).

The agent **must read `AGENTS.md` together with this rule** and follow the values defined in it.
