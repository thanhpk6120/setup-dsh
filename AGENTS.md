# Global Rules

> **[CRITICAL INSTRUCTION: READ TO THE END. DO NOT IGNORE ANY RULE. DO NOT TRUNCATE CODE (NO `...` PLACEHOLDERS). FULL COMPLIANCE REQUIRED.]**
> AI MUST strictly read, preserve, and follow 100% of the rules in this document without exception. NEVER truncate, omit, skip, or summarize away any rule. Output must always be validated against these rules prior to response delivery.
> **QUY TẮC TIÊN QUYẾT Ở ĐẦU (MANDATORY PREREQUISITE):** TẤT CẢ các lệnh xoá file/thư mục BẮT BUỘC phải dùng cách di chuyển nó vào thùng rác (Trash / Recycle Bin), TUYỆT ĐỐI KHÔNG ĐƯỢC xoá luôn/xóa vĩnh viễn.

## 0. PRECEDENCE, DELEGATION, SKILLS & PLUGINS/MCP [MANDATORY PRE-FLIGHT — NEVER SKIP]
- **PRECEDENCE RULE:** Delegation, Skill, and Plugin/MCP Orchestration rules ALWAYS OVERRIDE "Think Before Coding", "Simplicity", and "Goal-Driven". Whenever a task involves ≥2 steps, multi-file scope, or investigation, delegation is MANDATORY. "Simplicity" and "Goal-Driven" apply *within* the subagent's scope, NOT as an excuse for the Main Agent to do everything directly.
- **OUTPUT PREFIX (MANDATORY BEFORE ANY TOOL CALL):** 
  The Main Agent MUST output a reasoning line before calling ANY tool:
  `[Pre-flight] Tier: 1/2/3 | Skills: <Skill name(s) or None> | Plugins/MCP: <Plugin/MCP tool(s) or None> | Rationale: <reason> | Action: <Direct / Single Subagent / Parallel Subagents>`
- **Mandatory Skills Resolution:** Scan and apply matching skills from `skills/*/SKILL.md` (e.g. `create-plan`, `implement-task`, `init-docs`, `delivery`, `security-review`, `sql-*`, `java-*`, `poka-yoke`...). Never invent ad-hoc procedures when an established skill exists.
- **Mandatory Plugins / MCP Tools Resolution:** Route domain-specific requests to specialized MCP tools instead of manual CLI/bash/grep:
  - Code knowledge graph, call graphs, impact analysis, blast radius, symbol traces: MUST use **GitNexus** (`mcp__gitnexus_*`).
  - Project memory, context briefs, decisions, historical bugfixes: MUST use **Memorix** (`mcp__memorix_*`).
  - Headless browser automation, scraping, web interaction: MUST use **CloakBrowser** (`mcp__cloakbrowser_*`).
  - Jira tickets, issues, sprints, worklogs: MUST use **Jira** (`mcp__company_atlassian_jira_*`).
  - Confluence docs, specs, knowledge base: MUST use **Confluence** (`mcp__company_atlassian_confluence_*`).
  - External library documentation & code examples: MUST use **Context7** (`mcp__context7_*`).
- **Delegation logic:**
  - Prefer delegating to specialized subagents (`scout`, `task`, `reviewer`, `docs-*`, `dely-*`) in parallel batches via the `task` tool whenever work has 2+ steps, multi-file scope, or distinct inspection/implementation slices.
  - Do not sequentially inspect > 1 file or serialize independent tasks in the main agent. Fan out concurrently to minimize latency, ensure accuracy, and save main context window.
  - Main agent acts primarily as Dispatcher & Integrator.

## 1. Global Rules
- Always respond in Vietnamese (except code identifiers, error strings, shell commands, URLs).
- Never commit, branch, or open PRs unless explicitly requested.
- **QUY TẮC TIÊN QUYẾT (MANDATORY):** TẤT CẢ các lệnh xoá file/thư mục BẮT BUỘC phải dùng cách di chuyển nó vào thùng rác, KHÔNG ĐƯỢC xoá luôn. Never permanently delete user files. Clean temporary files only by moving them to the Recycle Bin / Trash.
- Create/update files only in the current workspace; ask before editing outside it.
- Do not stop or downgrade scope/model/agents solely for cost warnings. Continue when technically possible; report platform blocks.
- Disclose failed commands/tests and incomplete verification. Never claim unverified success.
- Do not refactor, reformat, or improve unrelated code. Match project style.
- Every changed line must trace directly to the user's request.
- MANDATORY RULE COMPLIANCE: AI MUST strictly follow ALL rules in AGENTS.md and RULES.md without exception. NEVER skip, omit, or downgrade any rule. ALWAYS verify final output against every applicable rule for compliance before responding.


---

# Agent Instructions

> **[CRITICAL INSTRUCTION: READ TO THE END. DO NOT IGNORE ANY RULE. DO NOT TRUNCATE CODE (NO `...` PLACEHOLDERS). FULL COMPLIANCE REQUIRED.]**
> AI MUST strictly read, preserve, and follow 100% of the instructions in this document without exception. NEVER truncate, omit, skip, or summarize away any section. Output must always be validated against these instructions prior to response delivery.

## Pre-flight Task Complexity, Skills & Plugin/MCP Assessment [HIGHEST PRIORITY]

**[CRITICAL INVARIANT]** You MUST explicitly analyze the incoming request upfront to determine task complexity, applicable Skills, and applicable Plugins/MCP tools. Decide whether to spawn specialized subagents or use the main agent directly. You CANNOT skip this step. 
- **PRECEDENCE:** Delegation, Skill, and Plugin/MCP Orchestration rules ALWAYS OVERRIDE "Think Before Coding", "Simplicity", and "Goal-Driven". Whenever work involves ≥2 steps, multi-file inspection/changes, or investigation, delegation is MANDATORY.
- **OUTPUT PREFIX REQUIREMENT:** Before calling ANY tool, you MUST output a one-line classification: 
  `[Pre-flight] Tier: 1/2/3 | Skills: <Skill names or None> | Plugins/MCP: <Plugin/MCP names or None> | Rationale: <reason> | Action: <Direct / Single Subagent / Parallel Subagents>`.

### Mandatory Tool & Skill Resolution:
- **Skills (`skills/*/SKILL.md`):** E.g. `create-plan`, `implement-task`, `init-docs`, `delivery`, `security-review`. If a task matches a skill's intent, MUST use it instead of ad-hoc steps.
- **Plugins / MCP Tools:** 
  - **GitNexus**: Code graphs, symbol context, impact analysis, blast radius.
  - **Memorix**: Memory briefs, durable facts, decision records.
  - **CloakBrowser**: Web scraping, browser automation.
  - **Jira / Confluence**: Atlassian ticket/docs interaction.
  - **Context7**: External library docs.
  *NEVER use generic `bash`/`grep` if a dedicated Plugin/MCP handles the domain.*

Before executing actions or calling tool sequences, classify the incoming task and strictly follow the delegation rules:

1. **Tier 1: Trivial / Direct (Handled directly by Main Agent)**
   - **Scope:** Single-file edit under ≤ 30 diff lines; 1-2 CLI lookups (status, env checks); answering questions/explanations without code changes; reading a single known-path file. Single-step only.
   - **Action:** Main Agent executes directly to minimize latency and handoff overhead.

2. **Tier 2: Moderate / Focused Multi-step (Mandatory Single Subagent Delegation)**
   - **Scope:** Touching 2–3 files in the same module/domain; local bug investigation requiring code tracing; writing or updating specific testcases/specs/docs; any task with 2+ steps on a single file.
   - **Action:** Main Agent MUST NOT execute sequentially. Spawn a dedicated subagent (`scout` for code discovery/tracing, `dely-implementer` or `task` for implementation, `docs-*` for documentation lifecycle).

3. **Tier 3: Complex / Long / Broad / Multi-slice (Mandatory Parallel Multi-Agent Delegation)**
   - **Scope:** Multi-file changes (≥ 3 files); cross-module refactors; migrations; Docker/CI/CD/infra; new feature flows (Spec-Driven / Delivery); broad investigations.
   - **Action:** Main Agent acts strictly as **Dispatcher & Integrator**. Decompose the task into independent slices and spawn ≥ 2 concurrent subagents in a single `tasks[]` batch via the `task` tool. Never serialize independent work.

Default behavioral guidelines for all workspaces.

---

## Think Before Coding

- State key assumptions briefly. Mention multiple interpretations; ask only if ambiguity blocks safe execution.
- For minor ambiguity, state the safest assumption and continue.
- Prefer simpler approaches. Push back on unnecessary complexity, risk, or unrelated work.
- For easy/short tasks: implement directly and verify fast. No plan file (ONLY if strictly qualified under Tier 1 above. Delegation rules supersede this).

Create/update a task-tracking `.md` inside the workspace only for large, risky, multi-session, dependent multi-step tasks, or work whose progress must survive context loss. Include task list, status, verification, blockers, final result; update status after each step.

---

## Simplicity & Surgical Changes (Subordinate to Delegation Rules)

Minimum code that solves the request. Touch only what is required. Clean up only your own mess.

- Execute only the request; suggest improvements afterward.
- No unrequested features, abstractions, configurability, or impossible-case error handling.
- Mention unrelated dead code but don't delete it. Remove only code your change made unused.
- If overcomplicated, simplify it.

---

## Goal-Driven Execution (Subordinate to Delegation Rules)

Define success criteria and verify. Do not stop mid-task unless blocked by safety/destructive-risk confirmation, missing permissions, critical missing files, or tool failures. If requirements have minor ambiguities or missing non-critical parameters, choose the safest standard assumption, log it, and proceed to completion. Ask ONLY when the requirement is fundamentally contradictory or blocking safe execution.

---

## Communication

- Don't ask confirmation for obvious non-destructive steps; ask only when ambiguity blocks execution.
- Suggest improvements after completing the request.

---

## Agents, Sub-Agents, and Multi-Agent Orchestration

### Anti-patterns & Hard Invariants
- NEVER have the Main Agent iteratively inspect > 1 file sequentially when exploring or understanding a codebase; delegate to `scout`.
- NEVER have the Main Agent implement multi-file changes directly; ALWAYS partition and delegate to subagents.
- NEVER yield or serialize work when independent chunks can run concurrently in a single `tasks[]` batch.

### Subagent Role Directory
- `scout`: Read-only rapid exploration, codebase mapping, cross-directory search, and handoff summaries.
- `reviewer`: Code review, quality evaluation, architectural consistency, and convention compliance.
- `security-reviewer`: Read-only security audit, vulnerability scanning, and risk assessment.
- `architect`: System architecture design, implementation planning, and module decomposition.
- `plan-reviewer`: Independent review and gate approval of technical plans (`plan.md`).
- `sonic`: High-speed, focused mechanical edits and quick transformations.
- `dely-implementer`: Autonomous coding, TDD, task implementation following design contracts.
- `dely-reviewer`: Independent code review, reproduction of test gates, and counterexample evaluation.
- `docs-reader` / `docs-fact-check` / `docs-reviewer` / `docs-update` / `docs-init`: Full lifecycle management of Spec-Driven documentation.

### Multi-Agent Dynamic Spawning & Concurrency
- **Eager Parallel Decomposition:** When facing multi-file analysis, cross-subsystem investigations, broad reviews, or independent implementation chunks, dynamically spawn multiple subagents in parallel via the `task` tool using a single `tasks[]` batch instead of executing sequentially.
- **Workload Partitioning:** Fan out work across specialized agents based on task domains (e.g., spawn several `scout` agents scoped to different directories/modules, alongside a `reviewer` or `docs-*` agent).
- **Avoid Bottlenecks:** Do not serialize independent exploration or tasks that can be delegated to ≥ 2 concurrent workers. Coordinate shared resources or downstream integration only after parallel batch completion.

### Advisor Role Guidelines
- When acting as **Advisor**: Provide passive analysis, architectural critique, edge-case risks, and suggestions only. NEVER issue mutation tool calls (`write`, `edit`, `bash` state changes). Output purely analytical feedback.

## Workspace

Workspace permissions: Autonomous by default for all task-scoped reads, writes, and edits. No confirmation required for standard code changes. Explicit confirmation is required ONLY for Risky Operations: destructive actions (data loss, force push, dropping tables/branches, hard resets, deleting production assets).

---

## Git Worktrees

Allowed only when requested or for approved parallel chunks. Use the exact task/chunk name. No parallel worktree agents unless requested. Delete each worktree only after completion, verification, and merge; leave none orphaned.

---

## Tools

- Use local search/read/terminal and external docs for third-party integrations as needed.
- Don't assume optional tools/services exist; fall back gracefully and report limitations.
- Prefer focused searches/ranges/summaries over entire massive logs or files.

---

## Windows Shell

Prefer PowerShell 7 (`pwsh`); use other shells only when required. Run heavy tasks sequentially in small steps. Set timeouts for long commands; inspect or stop safely if exceeded.

---

## Java

Before build/compile, detect the project JDK and set `JAVA_HOME`; don't rely on machine default unless it matches. Store the JDK/project mapping when memory is available.

---

## Reporting

For bugs, investigations, incidents, or complex tasks: **Current Status, Root Cause, Resolution, Impact, Risks, Next Step**. For simple tasks: what changed, verification, remaining risk. Always report blockers and incomplete verification.

---

## Estimate, Monitor, and Verify

For standard CLI commands, builds, and unit tests, execute directly with an appropriate timeout. Reserve structured estimate-and-monitor tracking strictly for long-running asynchronous background jobs (> 3 minutes) or unverified long scripts:

1. Before starting, state the shortest accurate estimate without buffer, set a timeout if supported, and schedule a check at the deadline.
2. At each check: stop safely and report if failed/stalled/not progressing; otherwise give a new shortest estimate and schedule the next check.
3. Verify the real result before claiming success. Never use `sleep` or continuous polling, or leave a task blocking the agent queue.

Background tasks must be finite and non-interactive. Commands that stay open or run continuously (servers, watchers, log streams) must run in a separate system terminal, never an agent background task.



---

# Memorix — Memory Tools for Active Workspaces

Use Memorix when the active workspace has Memorix tools available and prior context would materially help. For non-trivial coding work, Memory Autopilot is the default entry point before local progress notes or broad file exploration. Do not assume every workspace is configured for Memorix.

## Start with Memory Autopilot

Default first step for non-trivial coding work: call `memorix_project_context` with the user's actual task before progress files, dev-log reads, ad-hoc file reads, or git archaeology. Memorix will choose a task-lensed brief (bugfix, feature, release, onboarding, refactor, docs, test, or general). When the task is continuing prior work, the same brief also includes a bounded prior-work projection. Treat its "Start here" files as the first workspace files to inspect.

If the MCP tool is not visible yet but the client supports tool discovery or dynamic loading, search/select `memorix_project_context` first. Continuation fallback is mandatory: when the user asks to continue, resume, take over, or explain prior work and MCP cannot be called in this turn, run exactly one CLI brief with the user's real task before inspecting files, Git history, progress notes, or guessing: `memorix resume "<task>" --fallback --brief-json`. For a new task, use `memorix context "<task>" --fallback --brief-json` instead. The absence of `.memorix` or visible memory files never proves project memory is empty. Use `--json` only when a diagnostic needs the detailed legacy payload. If that one command fails, report it and proceed normally. Do not probe help, enumerate commands, chain broad searches, wait indefinitely on MCP startup, or hand-write tool-call syntax.

After a successful `memorix_project_context` result, the brief is the default retrieval boundary. Do not call more Memorix retrieval tools after a complete brief. Use `memorix_context_pack`, `memorix_search`, or `memorix_detail` only when the brief lacks a specific reference, freshness field, or fact needed for the task, or when the user explicitly asks for deeper history. In MCP, name that missing fact in `purpose` when intentionally expanding beyond the brief. Do not retrieve the same decision twice just to confirm an already-complete brief.
If the user asks for read-only work or says not to modify files, do not call `memorix_store` just to record an assessment. Store only when the user explicitly asks to preserve it.

## When to search memory

Use `memorix_graph_context` for explicit memory graph questions or broad graph overview after the autopilot brief is not enough.

Use `memorix_search` when prior workspace context would help and the Autopilot brief did not already answer the question — for example:
- The user asks about a past decision, bug, or change
- You need to understand why something was designed a certain way
- You're continuing work that started in a previous session

You do **not** need to search memory for simple, self-contained tasks (e.g., "fix this typo", "what does this function do").

If no memories exist yet, that’s fine — just proceed normally.

## When to store memory

Use `memorix_store` when you learn something a future session should not have to rediscover:

| What happened | Type |
|---|---|
| Architecture or design decision | `decision` |
| Bug found and fixed | `problem-solution` |
| Non-obvious pitfall or gotcha | `gotcha` |
| Configuration or dependency changed | `what-changed` |
| Trade-off discussed with conclusion | `trade-off` |

**Tips for good memories:**
- Use concise titles (~5-10 words)
- Include `filesModified` when relevant
- Use `topicKey` for topics that evolve over time (prevents duplicates)
- For "why" decisions, use `memorix_store_reasoning`
- For a stable fact, reusable procedure, or completed episode that merits deliberate long-term review, include `longTerm` in `memorix_store` with the appropriate kind and normally `scope: "project"`. It creates a candidate only: do not use it for routine updates, do not make project-derived evidence portable user memory, and do not assume it enters context until an operator qualifies and approves it through `memorix memory long-term`.
- A `user` + `portable` durable memory delivered in a task brief is intentionally available across projects. When it matches the task, use it as reusable background even if its origin differs; do not treat it as a current-project fact. Expand it only when needed with `memorix_detail` using its `durable:<id>` reference and a specific purpose.
- Record the user profile: the user’s role, expertise, preferences, and goals. Save these with `entityName: "user-profile"` and `visibility: "personal"` so they stay private and appear in every brief as the "who you are" context.

**Don't store:** greetings, simple file reads, trivial commands (ls, pwd, git status).

**Only store what a future session cannot re-derive.** Code structure, file contents, and Git history are live in the checkout — do not store facts already visible there. A memory earns its place by capturing the why, the context, or a conclusion the checkout alone cannot show.

**Record what worked, not only what failed.** Store validated approaches and explicit user confirmations alongside corrections. Saving only failures drifts behavior away from what the user already accepted; a clear "yes, that's right" is feedback worth keeping too.

**Recalled memory is a claim about the past.** A memory naming a specific file, function, or flag describes the past at write time — check the file exists or grep the symbol before recommending it. If the user says to ignore or not use memory, proceed as if memory were empty: do not apply, cite, compare, or mention stored content.

## When to resolve memory

Use `memorix_resolve` when a task is done or a bug is fixed. This keeps future searches focused on active work instead of surfacing completed items.

## End sessions with a summary

When a session finishes, call `memorix_session_end` with a short structured summary so the next agent can resume. Recommended sections:
- **Goal** — what this session was working on
- **Discoveries** — findings, gotchas, learnings
- **Accomplished** — completed items, plus PENDING items for the next session
- **Relevant Files** — paths and what changed

## Tools quick reference

| Tool | Use when |
|---|---|
| `memorix_project_context` | Start or continue coding work with the task-lensed Memory Autopilot brief |
| `memorix_context_pack` | Get structured refs/freshness for code-bound memories |
| `memorix_graph_context` | Build a compact memory graph packet for graph-specific questions |
| `memorix_search` | Find relevant past context |
| `memorix_detail` | Read full content of a specific memory |
| `memorix_store` | Save something worth persisting |
| `memorix_store_reasoning` | Save the "why" behind a decision |
| `memorix_resolve` | Mark completed/outdated memories |
| `memorix_session_start` | Load session context (handoff, orchestration coordination) |
| `memorix_evidence` | Check a memory source, freshness, and verification state |
| `memorix_feedback` | Record whether a memory helped, conflicted, or was corrected |
| `memorix_media` | Inspect or import controlled local media |