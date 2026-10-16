---
name: wayday-task-tracker
description: Track project tasks, record completions, and log activity in PLANNING.md and PROGRESS.md with contributor Git/GitHub identity.
---

# Wayday task tracker

Use this skill when planning, updating, or completing tasks across the Wayday project to keep teammates aligned.

## Responsibilities

- Read and parse [PLANNING.md](../../../PLANNING.md) to inspect active milestones and task statuses.
- Update task status (`[ ] TODO` -> `[-] IN_PROGRESS` -> `[x] DONE`) and assignees.
- Record completed work in [PROGRESS.md](../../../PROGRESS.md) with contributor Git and GitHub identity, date, and summary notes.
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
py .agents/skills/wayday-task-tracker/scripts/track_task.py start M1-01
```

### 3. Complete a Task
Mark a task as done, record the completion date, and append a formatted entry to `PROGRESS.md`:
```powershell
py .agents/skills/wayday-task-tracker/scripts/track_task.py done <TASK-ID> --notes "Implemented Drift database"
# Or with PowerShell:
./.agents/skills/wayday-task-tracker/scripts/track_task.ps1 done M1-01 -Notes "Implemented Drift database"
```

## Agent Guidelines

- When starting work on a milestone task, check [PLANNING.md](../../../PLANNING.md) first to ensure prerequisites are satisfied.
- Upon successfully verifying a completed task (e.g., passing `flutter test`, `flutter analyze`, or unit tests), invoke `track_task.py done <TASK-ID> --notes "..."` so the project documentation reflects verified work immediately.
- Never manually invent completed statuses without actual verification against the task's acceptance criteria.
