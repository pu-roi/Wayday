---
name: wayday-task-tracker
description: Track project tasks, record completions, and log activity in docs/wayday/PLANNING.md and docs/wayday/PROGRESS.md with contributor Git/GitHub identity.
---

# Wayday task tracker

Use this skill when planning, updating, or completing tasks across the Wayday project to keep teammates aligned.

The canonical files are `docs/wayday/PLANNING.md` and `docs/wayday/PROGRESS.md`. Run the commands below from the repository root; do not recreate root copies of these documents.

[README](../../../docs/wayday/README.md) owns the document index and product requirements; [Contributing](../../../docs/wayday/CONTRIBUTING.md#development-practices) owns development and verification guidance. Planning includes milestone outcomes and detailed task specifications, so do not create a separate roadmap, plan, or duplicate checklist. Progress records verified work and does not authorize starting future implementation.

## Responsibilities

- Read and parse [PLANNING.md](../../../docs/wayday/PLANNING.md) to inspect active milestones and task statuses.
- Update task status (`[ ] TODO` -> `[-] IN_PROGRESS` -> `[x] DONE`) and assignees.
- Record completed work in [PROGRESS.md](../../../docs/wayday/PROGRESS.md) with contributor Git and GitHub identity, date, and summary notes.
- Recalculate milestone progress metrics in the summary dashboard.

## Contributor Identity Resolution

The skill automatically identifies the current contributor using:
1. `git config user.name` and `git config user.email` (e.g., `Roi Cambe <roicambe02@gmail.com>`).
2. GitHub username extracted from the `origin` remote URL (e.g., `github.com/pu-roi/Wayday.git` -> `@pu-roi`) or the `GITHUB_ACTOR` environment variable.
3. System username fallback (`USERNAME` / `USER`).

No manual account entry is required.

## Commands

Run the companion CLI script using Python (`py` or `python3`) or PowerShell (`track_task.ps1`):

### 1. List Tasks
View all tasks, assignees, and current statuses:
```powershell
py .agents/skills/wayday-task-tracker/scripts/track_task.py list
# Or with PowerShell:
./.agents/skills/wayday-task-tracker/scripts/track_task.ps1 list
```

### 2. Start a Task
Mark a task as in progress and assign it to the current Git user:
```powershell
py .agents/skills/wayday-task-tracker/scripts/track_task.py start <TASK-ID>
# Example:
py .agents/skills/wayday-task-tracker/scripts/track_task.py start M2-01
```

### 3. Complete a Task
Mark a task as done, record the completion date, and append a formatted entry to `PROGRESS.md`:
```powershell
py .agents/skills/wayday-task-tracker/scripts/track_task.py done <TASK-ID> --notes "Verified acceptance criteria and recorded evidence"
# Or with PowerShell:
./.agents/skills/wayday-task-tracker/scripts/track_task.ps1 done <TASK-ID> -Notes "Verified acceptance criteria and recorded evidence"
```

## Agent Guidelines

- When starting work on a milestone task, check [PLANNING.md](../../../docs/wayday/PLANNING.md) first to ensure prerequisites are satisfied.
- Upon successfully verifying a completed task (e.g., passing `flutter test`, `flutter analyze`, or unit tests), invoke `track_task.py done <TASK-ID> --notes "..."` so the project documentation reflects verified work immediately.
- Never manually invent completed statuses without actual verification against the task's acceptance criteria.
