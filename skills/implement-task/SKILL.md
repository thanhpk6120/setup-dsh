---
name: implement-task
description: Implement approved tasks from tasks.md following Rule 02 (Implement Task). Use for executing tasks, producing report.md from real command output, handling deviations, and proposing Gate 2 docs diffs.
---

# Rule 02 — Implement Task

> **Audience:** AI agent. Follow the steps in order. Do not skip a step and do not invent a step.
> **Goal:** implement the approved tasks in `tasks.md`, produce `report.md` from **real** command output, produce `deploy.md` when required, and propose the docs diff for Gate 2.
> **Scope of this file:** this rule is **project-agnostic**. It must work unchanged for every project in the company.
> **Predecessor:** `docs/rules/create-plan.md`. This rule may only run on a plan that passed Gate 1.

---
## 0. Project configuration contract [READ THIS FIRST]

This rule contains **no project-specific hardcoded values**. All project configuration is defined in a single source of truth:

| File | What it provides |
|---|---|
| `{{PROJECT_ROOT}}/AGENTS.md` | Project overview, **service registry** (§4), tech stack (§5), quick rules & read order & verify commands (§10), agent working rules, code style & integration surfaces (§11), git rules (§13), do-not-touch list (§14) |

### Configuration keys resolved directly from `AGENTS.md`

The rule references these by name. Each `{{key}}` used in this file resolves from `AGENTS.md`:

| Key | Location in `AGENTS.md` | Meaning |
|---|---|---|
| `{{SERVICE_TAGS}}` | §4.1 | Canonical service tag list used in `plan.md` front matter and in the `Service` column of `tasks.md` |
| `{{LAYER_READ_ORDER}}` | §10.1 | Per stack, the order in which source files must be traced |
| `{{VERIFY_COMMANDS}}` | §10.2 | The exact lint/compile/test command per service |
| `{{DB_DOCS_PATH}}` | §11.1 | Where the current DB state of truth lives, and the migration file naming rule (`docs/database/`) |
| `{{IMPACT_TOOL}}` | §11.1 | Code-index / impact tool (`none` if unused) |
| `{{I18N_REQUIRED}}` | §11.1 | `true` / `false` (default `false`) |
| `{{INTEGRATION_SURFACES}}` | §11.1 | External and inter-service contracts that can break clients |
| `{{COMMON_IMPACT_ZONES}}` | §10.2 / §11.1 | Known "change X → affects Y at severity Z" mappings |
| `{{STATUS_VOCABULARY}}` | §11.1 | Allowed status values (`draft` → `plan-review` → `approved` → `in_progress` → `testing` → `done`) |
| `{{TASK_FORMAT}}` | §11.1 | `checklist` |
| `{{BRANCH_RULE}}` | §13.1 | Branch naming and pre-implementation branch check (`feature/CBCLOUDV2-<TICKET-NUMBER>-<slug>` hoặc `feature/<TICKET-ID>`) |
| `{{EXTRA_RULES}}` | §9 | Companion rules to read when relevant (`create-plan`, `create-testcase`, `init-docs`) |
| `{{APPROVAL_EVIDENCE}}` | §8.2 / §11 | Gate 1 approval evidence (`status: approved` in `plan.md` reviewed by TechLead) |
| `{{IMPLEMENT_ORDER}}` | §11.3 | Per stack, file implementation order within a task |
| `{{CODE_STYLE_RULES}}` | §11.3 | Layering, error handling, UTF-8 without BOM, Vietnamese comments/replies |
| `{{FORBIDDEN_CHANGES}}` | §11.2 / §14 | Changes requiring re-approval (unapproved contracts, schema, permissions, credentials) |
| `{{MOCKABLE_INTEGRATIONS}}`| §11.1 / §11.2 | Integrations mocked/stubbed locally (CloudHSM, EJBCA, Root CA) |
| `{{DEPENDENCY_POLICY}}` | §11.2 | New dependencies not allowed without TechLead approval |
| `{{REPORT_EVIDENCE}}` | §11.2 | Real terminal execution output for verification in `report.md` |
| `{{DEPLOY_TRIGGERS}}` | §11.2 | Change types that require `deploy.md` (DB, config, dependency, jobs) |
| `{{DEPLOY_COMMANDS}}` | §5 / §10.2 | Build & deploy commands |
| `{{DOCS_UPDATE_MAP}}` | §6 | Mapping change types to documentation files in `docs/` |
| `{{COMMIT_RULE}}` | §13.2 | Commit message format `<TICKET-ID>: <mô tả>` |
---

> **Multi-Agent Orchestration Contract:** Phiên chính đóng vai trò Dispatcher/Control. Sau khi Gate 1 duyệt, bắt buộc sử dụng tool `task` gọi agent `dely-implementer` (một hoặc nhiều slice song song) để thực hiện code thay vì tự code trong main agent. Xong code, gọi `dely-reviewer` kiểm tra độc lập.

> **MANDATORY EVIDENCE LOOP CONTRACT:**
> Mọi task thực thi BẮT BUỘC tuân thủ nghiêm ngặt vòng lặp kiểm chứng (Evidence Loop) trước khi hoàn thành:
> **Task execution** → Xuất file bằng chứng (`screenshot`/`json`/`txt`/`md`) → Lưu vào `docs/features/<TICKET-ID>/evidence/` → Tự verify đối chiếu với Acceptance Criteria → Sửa mã nguồn + cập nhật evidence + verify lại đến khi đạt mới được đánh dấu `done`.
## 1. When to run

- `plan.md` has passed Gate 1 (`status: approved`) and `tasks.md` is ready.
- A developer asks: *"Read `docs/rules/implement-task.md` and implement task N of `<TICKET-ID>`"*, or asks for the whole task list.

## 2. Stop conditions — check before touching any code

STOP and ask the user if any of these is true:

1. `plan.md` is not approved, or the approval evidence required by `{{APPROVAL_EVIDENCE}}` is missing. **The agent never sets `approved` itself.**
2. `tasks.md` is missing, or the requested task does not exist in it.
3. The target service cannot be resolved from the plan front matter through the `AGENTS.md` registry (Step 2).
4. The working tree has uncommitted staged changes or modified tracked files not related to the task (untracked files or build logs do not trigger this stop; ignore them and proceed).
5. The task requires a change listed in `{{FORBIDDEN_CHANGES}}` that the approved plan does not cover.
6. The impact analysis returns HIGH/CRITICAL risk that the plan did not anticipate (Step 5).
7. Implementation would have to deviate from the approved plan (Step 7) — stop, update the plan, get it re-approved.
8. The task is marked `blocked`, or its dependencies are not yet done.

---

## 3. Inputs and outputs

### Inputs
| Input | Source | Required |
|---|---|---|
| `docs/features/<TICKET-ID>/tasks.md` | Rule 01 | **Yes** — the approved scope |
| `docs/features/<TICKET-ID>/plan.md` | Rule 01 | **Yes** — the approved design |
| `docs/features/<TICKET-ID>/expect.md` | BA | **Yes** — the requirement of record |
| `docs/features/<TICKET-ID>/testcase.md` | docs / QA | If present — test cases to verify against before proposing the Gate 2 diff |
| `AGENTS.md` (project root) | project | **Yes** — service registry, conventions, quick rules, git rules |
| `docs/ARCHITECTURE.md`, `docs/specs/<domain>.md` | docs | **Yes** for the domains touched |
| `docs/DESIGN.md` | docs | When the task changes UI |
| `{{DB_DOCS_PATH}}` | docs | When the task touches data |
| Source code of the locked service | service repo | **Yes** |
### Outputs

| Output | Description |
|---|---|
| Code changes | Only inside the locked repo(s), only within approved scope |
| `docs/features/<TICKET-ID>/tasks.md` | Kept current, task by task, as work progresses |
| `docs/features/<TICKET-ID>/report.md` | Real changed files, real verification output, real problems |
| `docs/features/<TICKET-ID>/evidence/` | Real verification evidence (screenshot, json, txt, md) confirming acceptance criteria |
| `docs/features/<TICKET-ID>/impact.md` | Finalized to the real blast radius — **if the project uses it** (`{{EXTRA_RULES}}`) |
| `docs/features/<TICKET-ID>/deploy.md` | Only when a trigger in `{{DEPLOY_TRIGGERS}}` fires |
| Proposed docs diff | For Gate 2, per `{{DOCS_UPDATE_MAP}}` |

> All feature documents are written inside `docs/features/<TICKET-ID>/` in the docs repo. Scratch files generated by the tooling elsewhere are drafts only. If write permission is missing for that path, **ask for it** — do not write somewhere else.

---

## 4. Procedure

### Step 1 — Verify Gate 1 (hard gate)

1. Open `plan.md` and confirm the approval evidence required by `{{APPROVAL_EVIDENCE}}`.
2. Confirm `tasks.md` matches that plan (same feature, same services).
3. If any of it is missing → **STOP** and report that Gate 1 is not satisfied. Do not code "while waiting".

### Step 2 — Lock the target service (mandatory)

1. Read `service:` and `service-repo:` from the `plan.md` front matter, plus the `Service` column of the specific task.
2. Map the canonical `service-key` to its repo path through the **service registry in `AGENTS.md`**.
3. **Never** locate the service by grep, glob or folder-name similarity — service and folder names collide across repos and a search will match the wrong one.
4. Open and edit files **only** inside the locked repo path. A multi-service task is executed **one repo at a time**, each through its own registry path.
5. If `service:` is missing, the key is not in the registry, or the task spans repos without saying so → **STOP and ask.**

### Step 3 — Refresh and check the branch

```bash
cd <project-root>/docs && git pull
cd <project-root>/<locked-service> && git status && git pull
```

- Check `git status` **before** any checkout. If the tree is dirty → stop and ask.
- The branch must follow `{{BRANCH_RULE}}`. If the current branch is wrong, **ask before creating or switching** — never do it silently.
- Never merge or push unless explicitly asked (Step 13).

### Step 4 — Read context

1. `expect.md`, `plan.md`, the task row in `tasks.md`.
2. `AGENTS.md` service quick rules for the locked service.
3. `ARCHITECTURE.md`, and the `specs/<domain>.md` named by the plan.
4. `DESIGN.md` — if the task changes UI.
5. The i18n section of the plan and the existing locale files — if `{{I18N_REQUIRED}}` is true and the task produces user-visible text.
6. `{{DB_DOCS_PATH}}` — if the task touches data.
7. The real source files named in the plan, following `{{LAYER_READ_ORDER}}`.
8. `docs/features/<TICKET-ID>/testcase.md` — if present; the test cases the implementation must satisfy (Rule 03).

### Step 5 — Impact gate

If `{{IMPACT_TOOL}}` is not `none` and covers the locked service:

1. Run the tool's impact command **before changing any symbol** that is used outside its own file.
2. Read the blast radius; record the affected modules, APIs, models and components.
3. **HIGH/CRITICAL risk → stop, report to the developer, and wait for confirmation.** Do not continue on your own judgement.
4. If the tool is not set up or not indexed, follow the setup rule in `{{EXTRA_RULES}}`.

Regardless of the tool: read the real code, check `git diff`, and apply the severities in `{{COMMON_IMPACT_ZONES}}`. The tool assists analysis; it does not replace it.

### Step 6 — Implement, one task at a time

Loop over the tasks in `tasks.md` in order. For each task:

1. Set the task status to in-progress per `{{STATUS_VOCABULARY}}`, in `tasks.md`, **before** editing code.
2. Change files in the order given by `{{IMPLEMENT_ORDER}}` for that stack.
3. Follow `{{CODE_STYLE_RULES}}` — match the surrounding code, do not introduce a new pattern.
4. Respect the scope discipline in §5 of this rule.
5. Run the task's own verification command from `{{VERIFY_COMMANDS}}` and execute the **Mandatory Evidence Loop** (Step 8.1): run commands/tests, capture real output/artifacts into `docs/features/<TICKET-ID>/evidence/`, and self-verify against acceptance criteria. Iterate until 100% satisfied.
6. Mark the task done **only** when its DoD in `tasks.md` is objectively met, evidence is stored, and verifiable.
7. Record the commit/PR reference against the task if `{{COMMIT_RULE}}` requires it.

Special handling:

- **Data changes:** follow the migration rule in `{{EXTRA_RULES}}`. Never modify a database by hand when the project requires a migration. Update `{{DB_DOCS_PATH}}` in the same feature.
- **User-visible text:** when `{{I18N_REQUIRED}}` is true, add the translation keys per the plan. Never hardcode UI text, validation and error messages, empty states, buttons, tooltips, emails, notifications or exported documents. If the namespace or key is unclear → ask.
- **Unavailable integrations:** for anything in `{{MOCKABLE_INTEGRATIONS}}`, mock or skip it locally per the declared policy, and say so in `report.md`. Never enable a production integration from a development environment.
- **New dependencies:** only per `{{DEPENDENCY_POLICY}}`. Default is: not without approval.

### Step 7 — Deviation protocol

If reality does not match the approved plan — a file that does not exist, a contract that differs, a hidden dependency, an approach that cannot work:

1. **Stop implementing that task.**
2. Record the finding in `plan.md` §17 "Deviations found during implementation".
3. If the deviation changes design, scope, a contract, the schema, permissions, or anything in `{{FORBIDDEN_CHANGES}}` → **it needs re-approval before coding continues** (back to Gate 1 for that part).
4. If it is a minor, scope-preserving detail, record it in `plan.md` and in `report.md`, then continue.
5. Update `impact.md` whenever a newly affected file or service is discovered.

Never silently "fix" the plan by writing different code from what was approved.

### Step 8 — Verify with real output & Mandatory Evidence Loop

#### Step 8.1 — Mandatory Evidence Loop (Bắt buộc theo từng task)

Đối với mỗi task thực thi, BẮT BUỘC thực hiện đúng và đủ quy trình khép kín sau:
1. **Task Execution:** Triển khai mã nguồn/kịch bản tương ứng với task.
2. **Collect Evidence:** Thu thập bằng chứng thực tế dạng:
   - `screenshot` (`.png`/`.jpg`): Bắt buộc cho UI/UX hoặc kết quả trực quan.
   - `json` / `txt`: Output thực tế từ API response, log terminal, command output.
   - `md`: Ghi chú hoặc kịch bản chi tiết.
3. **Store Evidence:** Lưu toàn bộ file bằng chứng vào thư mục `docs/features/<TICKET-ID>/evidence/` (ví dụ: `docs/features/<TICKET-ID>/evidence/<task-id>-result.json`, `docs/features/<TICKET-ID>/evidence/<task-id>-screenshot.png`).
4. **Self-Verify vs Acceptance Criteria:** Tự đối chiếu, kiểm tra kỹ lưỡng bằng chứng thu được với từng tiêu chí chấp nhận (Acceptance Criteria) trong `expect.md` và DoD trong `tasks.md`.
5. **Iterate until Done:** Nếu chưa đạt tiêu chí hoặc phát sinh lỗi/lệch:
   - Sửa lại code/fix bug.
   - Chạy lại và cập nhật đè file bằng chứng mới vào `docs/features/<TICKET-ID>/evidence/`.
   - Tự verify lại.
   - Chỉ được đánh dấu task `done` khi và chỉ khi bằng chứng xác nhận thỏa mãn 100% acceptance criteria.

#### Step 8.2 — Verify with real commands output

1. Run the exact commands from `{{VERIFY_COMMANDS}}` for every service touched.
2. Run the broader checks required by `{{REPORT_EVIDENCE}}` (build, test suite, lint, regression flows).
3. If `{{IMPACT_TOOL}}` supports it, run its change-detection command to confirm nothing outside scope moved.
4. Review `git diff` file by file. Anything outside the task scope must be reverted or explained.
5. If `docs/features/<TICKET-ID>/testcase.md` exists, walk every test case whose scope this task covers. Each one must pass, or the failure/skip must be documented in `report.md` §4 or §5 with a verifiable reason. A feature must not be proposed for Gate 2 while an in-scope test case is failing and unexplained.

> **Test and validator output pasted into `report.md` must be the real output of a command that actually ran.** Narrating "tests pass" is a rejected output. If a check could not be run, write `N/A` with a verifiable reason.

### Step 9 — Write `report.md`

````markdown
---
feature: <TICKET-ID>
status: <in_progress | testing | done>
services: [<service-key>, ...]
updated_at: <YYYY-MM-DD>
---

# Report — <TICKET-ID>: <feature name>

## 1. Tasks completed
- [x] Task 1 — <what was actually done>
- [x] Task 2 — <what was actually done>
- [ ] Task 3 — <not done: reason>

## 2. Files changed
| Service | File | Change |
|---|---|---|
| `<service-key>` | `<repo-relative path>` | <one line> |

## 3. Verification results
<!-- Paste the REAL output of each command. No narration. -->
```
$ <command from {{VERIFY_COMMANDS}}>
<real output>
```
| Check | Result | Note |
|---|---|---|
| `<lint command>` | ✅ / ❌ / N/A | |
| `<test command>` | ✅ / ❌ / N/A | tests run: X, failures: 0, errors: 0, skipped: Y |
| `<build command>` | ✅ / ❌ / N/A | |
| i18n — no hardcoded text, locales complete | ✅ / ❌ / N/A | <required when {{I18N_REQUIRED}} = true> |
| Impact/change detection | ✅ / ❌ / N/A | |
| Regression flows re-run | ✅ / ❌ / N/A | |
| `testcase.md` cases in scope | ✅ / ❌ / N/A | <required when docs/features/<TICKET-ID>/testcase.md exists; list failing/skipped TC ids> |

## 4. Deviations from the plan
<What differed from the approved plan, and how it was resolved. "None" if none.>

## 5. Problems and limitations
<Errors hit, workarounds applied, anything mocked or skipped per {{MOCKABLE_INTEGRATIONS}}, known limitations. "None" if none.>

## 6. Found outside scope — not fixed
<Problems noticed but deliberately not touched, with enough detail to file a ticket. "None" if none.>

## 7. Docs / specs status
- Related spec: `docs/specs/<domain>.md` / N/A
- Status: `updated` / `N/A (verifiable reason)` / `pending review (diff below)`

## 8. Proposed docs diff (Gate 2)
- [ ] `docs/specs/<domain>.md` — <what changes>
- [ ] `docs/ARCHITECTURE.md` — <what changes>
- [ ] `docs/DESIGN.md` — <what changes>
- [ ] `{{DB_DOCS_PATH}}` — <what changes>

## 9. Commits / PRs
| Service | Branch | Commit / PR | Note |
|---|---|---|---|
````

### Step 10 — Finalize `impact.md`

If the project uses `impact.md`, update it so it reflects reality after implementation: the files and services actually changed, the areas **confirmed** unaffected, the risks that materialized, and anything left unverified. Follow the impact rule in `{{EXTRA_RULES}}`.

### Step 11 — Write `deploy.md` when triggered

Create `deploy.md` **only** when a trigger in `{{DEPLOY_TRIGGERS}}` fires. Default triggers: schema/migration, config or environment variables, new dependency, new or changed job/cron/queue, message contract change, auth realm/role/permission change, storage bucket/path/policy change, infrastructure or rollout change.

````markdown
# Deploy — <TICKET-ID>

## 1. Summary
<What operations must do, in one paragraph.>

## 2. Database
- Migration file: `<name per {{DB_DOCS_PATH}}>`
- Command: `<from {{DEPLOY_COMMANDS}}>`
- Manual SQL (if any):
```sql
-- what it changes and why
```
- Effect on existing data:
- Who runs it: <DBA / DEV / CI>

## 3. Configuration
| Key | Old | New | Service | Note |
|---|---|---|---|---|

## 4. Dependencies
- `<install command>`

## 5. Jobs / queues / scheduled work
<New or changed, plus what must be restarted.>

## 6. Integrations
<Message topics, RPC contracts, auth config, storage — per {{INTEGRATION_SURFACES}}.>

## 7. Deployment order
1. <step>
2. <step>

## 8. Verification after deploy
- <check> → <expected result>

## 9. Rollback
- <exact steps to undo, per {{DEPLOY_COMMANDS}}>
````

> `deploy.md` describes **this feature's** rollout. Environment-level operating detail belongs in the service-local deployment doc named by `{{DOCS_UPDATE_MAP}}`, not in the shared docs repo.

### Step 12 — Propose the docs diff (Gate 2)

Map each change to its document using `{{DOCS_UPDATE_MAP}}`. The default mapping:

| Change | Document to update |
|---|---|
| Business logic, input/output, state, permissions | `docs/specs/<domain>.md` |
| Architecture, integrations, queues, storage, auth | `docs/ARCHITECTURE.md` |
| UI pattern, layout, component, theme | `docs/DESIGN.md` |
| Schema, entity, data | `{{DB_DOCS_PATH}}` |
| Service-specific coding convention | The service convention doc |
| Environment deployment steps | The service-local deployment doc |
| A new error and its resolution | The service-local troubleshooting doc |

Rules:

- The agent **proposes** a diff/PR on the docs repo. **The TechLead approves before merge (Gate 2).** Wrong docs poison every later plan.
- If no spec update is needed, `report.md` must state `Docs/specs: N/A` with a verifiable reason.
- A feature must not be marked `done` while the docs/specs status is missing.

### Step 13 — Close out

Per-task close-out:
- [ ] The task's DoD in `tasks.md` is objectively met.
- [ ] Mandatory Evidence Loop hoàn thành: Bằng chứng (screenshot/json/txt/md) đã được lưu đầy đủ vào `docs/features/<TICKET-ID>/evidence/`.
- [ ] Tự verify đối chiếu đạt 100% Acceptance Criteria so với `expect.md` và `tasks.md`.
- [ ] Its verification command was run and the real output is in `report.md`.
- [ ] `tasks.md` status updated, with the date.
- [ ] Commit/PR reference recorded if `{{COMMIT_RULE}}` requires it.

Feature close-out (Definition of Done):
- [ ] Every task in `tasks.md` is `done` — none left in progress or blocked.
- [ ] `report.md` contains real verification output for every affected service.
- [ ] `impact.md` finalized, if the project uses it.
- [ ] `deploy.md` exists if any `{{DEPLOY_TRIGGERS}}` fired.
- [ ] `{{DB_DOCS_PATH}}` updated, or the reason for waiting on the DBA is recorded.
- [ ] i18n complete with no hardcoded text, if `{{I18N_REQUIRED}}` is true.
- [ ] Every in-scope case in `docs/features/<TICKET-ID>/testcase.md` passes, or each failure is documented in `report.md` — if that file exists.
- [ ] Docs/specs status recorded and the Gate 2 diff proposed.
- [ ] `plan.md` marked complete, or the remaining scope stated explicitly.
- [ ] `git diff` contains nothing outside the approved scope.

Commit, push, merge and deploy follow `{{COMMIT_RULE}}` and the git rules in `AGENTS.md`. **The agent never commits, pushes, merges or deploys unless explicitly asked**, and stops to ask if the diff contains files outside the task scope or anything resembling a secret or runtime config.

If work is stopped unfinished, the agent reports: current status, remaining tasks, blockers, and every repo/branch/file left dirty.

---

## 5. Scope discipline

1. **Implement only what `tasks.md` approves.** Nothing else.
2. **No opportunistic refactoring.** Improvements outside the task go to `report.md` §6, not into the diff.
3. **No unapproved contract changes** — API shape, message payload, RPC contract, schema, permissions, config. See `{{FORBIDDEN_CHANGES}}`.
4. **No new dependencies** outside `{{DEPENDENCY_POLICY}}`.
5. **Match the existing code style** — naming, layering, error handling, logging, comment language, per `{{CODE_STYLE_RULES}}`.
6. **Never touch** the paths in the do-not-touch list of `AGENTS.md` (build output, vendor directories, secrets, runtime config, legacy copies).
7. **Problems found outside the task are reported, not fixed.**
8. **Ask when blocked.** Never guess business rules, data shapes or permissions in the middle of implementation.

---

## 6. Rejected outputs

The work is sent back if any of these is present:

| Anti-pattern | Why it fails |
|---|---|
| `report.md` claims "tests pass" with no pasted output | Unverifiable; the report is the evidence |
| Thiếu bằng chứng hoặc bỏ qua Mandatory Evidence Loop | Không có file bằng chứng trong `docs/features/<TICKET-ID>/evidence/` đối chiếu với Acceptance Criteria |
| Code written before Gate 1 approval | The gate exists to prevent exactly this |
| The service was found by grep instead of the registry | Wrong repo edited; registry exists to prevent it |
| The diff contains unrelated refactoring | Reviewer cannot separate the feature from the noise |
| Schema changed directly instead of via migration | Environments drift and cannot be reproduced |
| Hardcoded user-visible text in a multi-language project | Breaks localization silently |
| Plan deviated from without updating `plan.md` | The approved design and the code no longer match |
| `deploy.md` missing while a deploy trigger fired | Production breaks at rollout |
| Feature marked `done` with tasks still open, or docs status missing | The definition of done was not met |
| Committed, pushed or merged without being asked | Removes the human decision point |

---

## 7. Project customization

All project configurations live in:

👉 **`AGENTS.md`** at the project root (service registry, tech stack, quick rules, agent working rules, git rules, do-not-touch list).

The agent **must read `AGENTS.md` together with this rule** and follow the values defined in it.
