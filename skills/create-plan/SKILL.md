---
name: create-plan
description: Turn feature requirements (expect.md) into plan.md and tasks.md following Rule 01 (Create Plan). Use for planning, drafting tasks, requirement tracing, and impact analysis.
---

# Rule 01 — Create Plan

> **Audience:** AI agent. Follow the steps in order. Do not skip a step and do not invent a step.
> **Goal:** turn `expect.md` (written by BA) plus the project's base docs into a `plan.md` and `tasks.md` that another developer could implement without asking further questions.
> **Scope of this file:** this rule is **project-agnostic**. It must work unchanged for every project in the company.

---

## 0. Project configuration contract [READ THIS FIRST]

This rule contains **no project-specific hardcoded values**. All project-specific facts live in a single source of truth:

| File | What it provides |
|---|---|
| `{{PROJECT_ROOT}}/AGENTS.md` | Project overview, **service registry** (§4), tech stack (§5), quick rules & read order & verify commands (§10), agent working rules & integration surfaces (§11), git rules (§13), do-not-touch list (§14) |

### Configuration keys resolved directly from `AGENTS.md`

The rule references these by name. Each `{{key}}` used in this file resolves from `AGENTS.md`:

| Key | Location in `AGENTS.md` | Meaning |
|---|---|---|
| `{{SERVICE_TAGS}}` | §4.1 | Canonical service tag list used in `plan.md` front matter and in the `Service` column of `tasks.md` |
| `{{LAYER_READ_ORDER}}` | §10.1 | Per stack, the order in which source files must be traced (e.g. controller → service → repository → model) |
| `{{VERIFY_COMMANDS}}` | §10.2 | The exact lint/compile/test command per service |
| `{{DB_DOCS_PATH}}` | §11.1 | Where the current DB state of truth lives, and the migration file naming rule (`docs/database/`) |
| `{{IMPACT_TOOL}}` | §11.1 | Code-index / impact tool, the services it indexes, and its commands (`none` if unused) |
| `{{I18N_REQUIRED}}` | §11.1 | `true` / `false`. When `true`, the i18n plan section and the i18n task group are mandatory (default `false`) |
| `{{INTEGRATION_SURFACES}}` | §11.1 | External and inter-service contracts that can break clients (gRPC proto, REST APIs, HSM PKCS#11, EJBCA SOAP) |
| `{{COMMON_IMPACT_ZONES}}` | §10.2 / §11.1 | Known "change X → affects Y at severity Z" mappings |
| `{{STATUS_VOCABULARY}}` | §11.1 | Allowed status values (`draft` → `plan-review` → `approved` → `in_progress` → `testing` → `done`) |
| `{{TASK_FORMAT}}` | §11.1 | `checklist` or `table` or `block` — which `tasks.md` layout this project uses (`checklist`) |
| `{{BRANCH_RULE}}` | §13.1 | Branch naming rule (`feature/CBCLOUDV2-<TICKET-NUMBER>-<slug>` hoặc `feature/<TICKET-ID>`) |
| `{{EXTRA_RULES}}` | §9 | Companion rules to read when relevant (`init-docs`, `create-testcase`, `implement-task`) |
---

## 1. When to run

- BA has finished `docs/features/<TICKET-ID>/expect.md`.
- A developer asks: *"Read `docs/rules/create-plan.md` and execute it for `<TICKET-ID>`"*.

## 2. Stop conditions — check before doing anything

STOP and ask the user if any of these is true:

1. `docs/features/<TICKET-ID>/expect.md` does not exist.
2. `docs/` is not present beside the service repos (wrong workspace layout — see `AGENTS.md` §3).
3. The feature already has a `plan.md` with `status: approved` or later, and the user did not explicitly ask to redo it. **Never overwrite an approved plan.**
4. `expect.md` fails the Definition of Ready check in Step 2.
5. The base docs contradict the real source code in the area being changed, and there is no basis to decide which one is right.
6. The target service cannot be resolved unambiguously (Step 3).

---
## 3. Inputs and outputs

### Inputs

| Input | Source | Required |
|---|---|---|
| `docs/features/<TICKET-ID>/expect.md` | BA | **Yes** — source of truth for requirements |
| `docs/features/<TICKET-ID>/extract/` | BA / customer | If present — attached supporting documents |
| `AGENTS.md` (project root) | project | **Yes** — service registry, conventions, quick rules, git rules |
| `docs/ARCHITECTURE.md` | docs | **Yes** |
| `docs/specs/<domain>.md` | docs | **Yes** for every domain the feature touches |
| `{{DB_DOCS_PATH}}` | docs | **Yes** when the feature touches data |
| `docs/DESIGN.md` | docs | When the feature has UI |
| `{{EXTRA_RULES}}` | docs | When the trigger condition of that rule applies |
| Source code of the affected services | service repos | **Yes** — read only enough to establish scope, files and risk |
### Outputs

| Output | Description |
|---|---|
| `docs/features/<TICKET-ID>/plan.md` | Implementation design, using the template in Step 6 |
| `docs/features/<TICKET-ID>/tasks.md` | Task checklist split by service, using the template in Step 7 |
| `docs/features/<TICKET-ID>/impact.md` | First draft of the impact assessment, **if the project uses it** (see `{{EXTRA_RULES}}`) |
| Feature status | Set to `plan-review`, with the affected services recorded |

> **Output location is mandatory.** Both files must be written inside `docs/features/<TICKET-ID>/` in the docs repo. Any scratch plan the tooling generates elsewhere (for example a harness-internal plan file) is a draft only and must never be used as the deliverable. If the agent lacks write permission for that path, it must **ask for write access to that exact path** — it must not silently write somewhere else.

---

## 4. Procedure
> **Multi-Agent Orchestration Contract:** Phiên chính đóng vai trò Dispatcher/Control. Bắt buộc sử dụng tool `task` gọi agent `architect` (hoặc `scout`) để phân tích yêu cầu, khảo sát code và soạn thảo `plan.md`/`tasks.md`. Không tự động thực thi tuần tự trong main agent. Sau khi hoàn thành plan, gọi `plan-reviewer` đánh giá trước khi gửi người dùng duyệt.


### Step 1 — Refresh context

```bash
cd <project-root>/docs && git pull
```

Then read, in this order:

1. `expect.md` in full — what to build, what is explicitly **out of scope**, and the acceptance criteria.
2. Anything in `extract/`.
3. `AGENTS.md` — service registry (§4), conventions, quick rules (§10), agent working rules (§11), git rules (§13).
4. `ARCHITECTURE.md`.
5. The `specs/<domain>.md` of every domain touched.
6. `{{DB_DOCS_PATH}}` if data is involved; `DESIGN.md` if UI is involved.
7. Real source code of the affected services — **only enough** to determine scope, files and risk. Do not browse the repository at large.
If the spec and the real code disagree, record it under **Open questions**. Do not silently pick a side.

### Step 2 — Definition of Ready check (mandatory)

Check `expect.md` against this list:

- [ ] Acceptance criteria are measurable and unambiguous.
- [ ] Out-of-scope is stated explicitly.
- [ ] Actors, roles and permissions are clear.
- [ ] Main inputs, outputs and state transitions are clear.
- [ ] Edge cases, error states and existing/legacy data are addressed where relevant.
- [ ] The BA's own "open questions" have been answered, or are carried into blocking questions.

**If ambiguity blocks safe execution or fundamentally affects security/data architecture → STOP**, list the blocking questions, and ask the user. For minor ambiguities, make the safest reasonable assumption, record it clearly under **## 14. Assumptions**, and proceed with the plan.

In that case, write only a blocking draft: `status: draft`, the `Blocking questions` section filled in, and a note that planning cannot proceed. Do **not** write detailed design or implementation tasks yet.

Small assumptions that genuinely cannot be avoided go into the **Assumptions** section, one line each, so the reviewer can confirm them individually.

### Step 3 — Resolve the target service (mandatory)

1. The target service comes from, in priority order: the user's explicit statement in this session → `plan.md` front matter (when revising an existing plan) → the `Service` column of `tasks.md`.
2. Map it to a repo path through the **service registry in `AGENTS.md`**. Use the canonical `service-key`, never the git repo name and never a folder name guessed by similarity.
3. **Never discover the target service by grep, glob or name similarity.**
4. If the service is undeclared, the key is not in the registry, or one task would span more than one repo without being stated → **STOP and ask.**
5. Record the resolved `service` and `service-repo` in the `plan.md` front matter.

### Step 4 — Impact analysis

Do this **per acceptance criterion**, not for the feature as a whole.

For each AC:

1. Identify the affected services using `{{SERVICE_TAGS}}`.
2. Trace the file chain in each affected service following `{{LAYER_READ_ORDER}}` for that stack. Name concrete files, classes and methods — not layers in the abstract.
3. **Data:** compare against the current state in `{{DB_DOCS_PATH}}` **before** proposing any change. Record tables/columns added or modified, data types, nullability, defaults, indexes, and the effect on existing rows. Never propose a migration that contradicts the documented current state (duplicate column, broken relation, wrong type). If the documented state disagrees with the real schema/migrations, raise it under Open questions.
4. **UI:** identify page/component, API module, state/query layer, routing and styles, per `DESIGN.md`.
5. **Contracts:** for each surface listed in `{{INTEGRATION_SURFACES}}`, state whether the change is backward compatible, and name the clients at risk if it is not.
6. **Cross-service:** anything sharing a schema, a domain or a contract with another service must be listed and split into per-service tasks.
7. Consult `{{COMMON_IMPACT_ZONES}}` and apply the severity it assigns.
8. If `{{IMPACT_TOOL}}` is not `none` and covers the affected service → **run it before proposing any change to a symbol.** The tool assists; reading the real code and the real diff is still mandatory.

### Step 5 — Choose the approach

- Prefer the approach that fits the existing architecture over the one that is cheapest to type.
- Split the work into phases or vertical slices that leave the system working after each phase.
- Build foundations first; state explicitly what must be sequential and why.
- If there is a genuine design choice, document the alternatives and why they were rejected. **Any significant architectural decision must be surfaced in the plan for the TechLead to decide at Gate 1** — the agent does not decide it alone.

### Step 6 — Write `plan.md`

````markdown
---
feature: <TICKET-ID>
title: <feature name>
status: draft            # draft → plan-review → approved   (or {{STATUS_VOCABULARY}})
service: <canonical service-key from the AGENTS.md registry>
service-repo: <repo path matching the registry>
services-affected: [<key>, <key>]
owner: <DEV name / AI>
created_at: <YYYY-MM-DD>
updated_at: <YYYY-MM-DD>
---

# Plan — <TICKET-ID>: <feature name>

## 1. Blocking questions
<Must be resolved before approval. Write "None" if there are none.>

## 2. Approach summary
<3–5 lines: how this satisfies expect.md, and which services it touches.>

## 3. Requirement trace
| AC in `expect.md` | Covered by section |
|---|---|
| AC-1 | §5.1 |
<Every AC must appear. Any AC not covered must be explained here.>

## 4. Affected services
| Service | Severity | Main change |
|---|---|---|

## 5. Detailed design, per acceptance criterion
### 5.1 AC-1 — <name>
- **Approach:** <logic, algorithm, state transitions>
- **API:** <method + path + request + response + error cases>, or "None"
- **Backend:** <files / classes / methods, following {{LAYER_READ_ORDER}}>
- **Frontend:** <page / component / API module / state / route / style>, or "None"
- **Data:** <tables, columns, queries>, or "None"
- **i18n:** <keys, locale namespace/file, fallback, no hardcoded text>   <!-- required when {{I18N_REQUIRED}} = true -->
- **Docs to update:** <spec / architecture / design / database>

### 5.2 AC-2 — <name>
...

## 6. Implementation order
<Dependencies between parts: what goes first and why.>

## 7. Database changes
<"None", or: table/column, type, nullable, default, index, migration file name per {{DB_DOCS_PATH}}, effect on existing data, rollback. Any change here requires a corresponding task in tasks.md marked (*) and an entry in deploy.md.>

## 8. Configuration changes
<"None", or: env vars, config keys, permissions, auth realm, storage, queues.>

## 9. External and inter-service integrations
<"None", or one line per surface in {{INTEGRATION_SURFACES}} with the compatibility verdict.>

## 10. Backward compatibility
<Which existing clients/consumers could break, and the mitigation: versioning, dual-write, feature flag, staged rollout. "None" if not applicable.>

## 11. Verification plan
<Per affected service: the exact command from {{VERIFY_COMMANDS}}, plus what result proves the AC. Generic entries such as "run tests" are not acceptable. Include the regression flows that must be re-run.>

## 12. Risks and rollback
| Risk | Severity | Mitigation / rollback |
|---|---|---|

## 13. Alternatives considered
<Significant options and why they were rejected. "None" if there was no real choice.>

## 14. Assumptions
<One line per assumption the reviewer must confirm.>

## 15. Open questions
- [ ] <question> → Answer:

## 16. Proposed docs updates (Gate 2)
<What will change in specs/, ARCHITECTURE.md, DESIGN.md, {{DB_DOCS_PATH}}.>

## 17. Deviations found during implementation
<Leave empty. Filled in by Rule 02 while implementing.>
````

**Quality bar:** §5 must be detailed enough that a different developer can implement it without asking questions. Sentences like "adjust service X accordingly" are rejected.

Sections that evaluate to "None" are kept with the word `None` — never deleted, so the reviewer can see they were considered.

### Step 7 — Write `tasks.md`

Use the layout named by `{{TASK_FORMAT}}`. Default is `checklist`.

**Format A — checklist (default)**

````markdown
---
feature: <TICKET-ID>
status: plan-review
owner: <AI / DEV>
updated_at: <YYYY-MM-DD>
---

# Tasks — <TICKET-ID>

## <service-tag-1>
- [ ] [<service-tag>] <specific task> (M) — DoD: <objectively checkable result> — Verify: `<command from {{VERIFY_COMMANDS}}>` — Depends on: —
- [ ] [<service-tag>] <specific task> (S) — DoD: ... — Verify: ... — Depends on: task 1

## <service-tag-2>
- [ ] [<service-tag>] ... 

## database / config          <!-- only if §7 or §8 of the plan is not "None" -->
- [ ] [db] <migration + docs update> (*) (S) — DoD: migration applied and {{DB_DOCS_PATH}} updated — Depends on: ...

## i18n                        <!-- required when {{I18N_REQUIRED}} = true -->
- [ ] [i18n] <translation keys for UI / API messages / email / notifications / exports> (S) — DoD: no hardcoded strings; all locales present

## Feature close-out           <!-- always present -->
- [ ] Run the verification commands for every affected service and write `report.md` from the **real** output
- [ ] Complete `deploy.md` if there is any DB / config / dependency / job / queue change
- [ ] Produce the proposed docs diff for Gate 2: specs/, ARCHITECTURE.md, DESIGN.md, {{DB_DOCS_PATH}}
````

**Format B — block (use when tasks need more structure)**

````markdown
## Task N — <short descriptive title>

- Status: pending
- Service: `<canonical service-key>`
- Description: <one paragraph: the exact outcome>
- Acceptance criteria:
  - [ ] <specific, testable condition traced to an AC in expect.md>
- Verification:
  - [ ] `<exact command>` → <expected result>
- Dependencies: None
- Likely touched files:
  - `<repo>/<path>`
- Estimated scope: S
````

**Task rules (apply to every format)**

- Every task carries a service tag from `{{SERVICE_TAGS}}`, a size, a DoD and its dependencies.
- Size: `XS` ≈ 1 file · `S` ≈ 1–2 files · `M` ≈ 3–5 files · `L` ≈ 6–8 files. A task should fit in one working day.
- **Split** any task that touches more than 8 files, spans independent subsystems, has vague acceptance criteria, or joins unrelated work with "and" in its title. Avoid `L`.
- Status markers: `[ ]` not started · `[/]` in progress · `[x]` done (with date) · `[blocked]` (with reason). Or `{{STATUS_VOCABULARY}}` if the project overrides them.
- Mark `(*)` any task involving DB, config, dependency, job or queue changes — each `(*)` task must have a matching entry in `deploy.md`.
- The "Feature close-out" group is always present.
- Every task must trace back to an AC in `expect.md`. A task that traces to nothing is out of scope — move it to Open questions instead.

### Step 8 — Gate 1

Self-review checklist before submitting:

- [ ] `git pull` was run in `docs/`.
- [ ] `plan.md` has `service:` + `service-repo:` matching the `AGENTS.md` registry, and the `Service` column of `tasks.md` uses the same keys.
- [ ] Every blocking question is answered, or the plan is explicitly a blocking draft.
- [ ] Every AC in `expect.md` appears in the requirement trace (§3).
- [ ] The design does not contradict `specs/`, `ARCHITECTURE.md`, `DESIGN.md` or `{{DB_DOCS_PATH}}`.
- [ ] Every DB proposal was checked against the documented current state.
- [ ] Backward compatibility was assessed for every surface in `{{INTEGRATION_SURFACES}}`.
- [ ] Every task has a service tag, a size, a DoD, dependencies and a concrete verification command.
- [ ] No task is oversized or mixes unrelated subsystems.
- [ ] Risks, mitigation, rollback and deployment implications are documented.
- [ ] i18n is covered, if `{{I18N_REQUIRED}}` is true.
- [ ] The "Proposed docs updates (Gate 2)" section is filled in.
- [ ] `plan.md` and `tasks.md` are written inside `docs/features/<TICKET-ID>/`.
- [ ] **No code has been written.**

Then:

1. Write `plan.md` and `tasks.md` into `docs/features/<TICKET-ID>/`.
2. Draft `impact.md` if the project uses it.
3. Set the feature status to `plan-review` and record the affected services.
4. Summarize for the user: the main design decisions, the assumptions awaiting confirmation, and the remaining open questions.

> **Gate 1 is hard.** `plan.md` must be reviewed by DEV and approved by the TechLead (`status: approved`) before Rule 02 (implementation) may run. If it is not approved, revise from Step 5 and repeat.

> **Before implementation starts:** check out the correct branch per `{{BRANCH_RULE}}`. If the current branch is not the feature branch, ask the user before creating or switching — and never switch while the working tree is dirty.

---

## 5. Principles

1. **Ask when context is missing.** Never invent business rules, logic, data shapes or permissions.
2. **`expect.md` is the source of truth for requirements.** A plan that contradicts it is wrong by definition.
3. **The documented DB state is the source of truth for the schema.** Every DB proposal starts from it.
5. **No code in this rule.** This rule only analyses and plans.
6. **Follow project conventions** as declared in `AGENTS.md`.
7. **Never overwrite an approved plan.**
8. **Name things concretely.** Real files, real endpoints, real columns, real commands.
9. **This rule file stays generic.** Anything project-specific belongs in `AGENTS.md`, never hardcoded in logic.

## 6. Rejected outputs

A plan is sent back if it contains any of these:

| Anti-pattern | Why it fails |
|---|---|
| "Modify service X accordingly" | Not implementable without asking |
| "Run tests" as the verification plan | No command, no expected result |
| A task with no DoD | Cannot be objectively closed |
| A migration written without reading the documented schema | Risks conflicting with the real database |
| A target service inferred from a folder name | The registry exists precisely to prevent this |
| Sections deleted instead of marked "None" | The reviewer cannot tell if it was considered |
| Features present in the plan but absent from `expect.md` | Scope creep past the BA's decision |
| A plan written while blocking questions are open | Guesswork dressed as design |

---

## 7. Project customization

All project configurations live in:

👉 **`AGENTS.md`** at the project root (service registry, tech stack, quick rules, agent working rules, git rules).

The agent **must read `AGENTS.md` together with this rule** and follow the values defined in it.
