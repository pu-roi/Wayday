#!/usr/bin/env python3
"""
Wayday Task Tracker CLI & Automation Tool

Tracks tasks across PLANNING.md and PROGRESS.md, automatically capturing
the contributor's Git and GitHub identity.
"""

import argparse
import datetime
import os
import re
import subprocess
import sys
from pathlib import Path


def get_repo_root() -> Path:
    """Find the root directory of the git repository."""
    try:
        output = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        return Path(output)
    except Exception:
        current = Path.cwd().resolve()
        for p in [current, *current.parents]:
            if (p / ".git").exists() or (p / "PLANNING.md").exists():
                return p
        return current


def get_contributor_info() -> dict:
    """Detect contributor's name, email, and GitHub handle."""
    name = ""
    email = ""
    github = ""

    try:
        name = subprocess.check_output(
            ["git", "config", "user.name"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except Exception:
        name = os.environ.get("GIT_AUTHOR_NAME") or os.environ.get("USERNAME") or "Contributor"

    try:
        email = subprocess.check_output(
            ["git", "config", "user.email"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except Exception:
        email = os.environ.get("GIT_AUTHOR_EMAIL") or ""

    github = os.environ.get("GITHUB_ACTOR", "")
    if not github:
        try:
            remote_url = subprocess.check_output(
                ["git", "remote", "get-url", "origin"],
                stderr=subprocess.DEVNULL,
                text=True,
            ).strip()
            m = re.search(r"github\.com[:/]([^/]+)/", remote_url)
            if m:
                github = m.group(1)
        except Exception:
            pass

    assignee_str = name
    if github:
        assignee_str = f"{name} (@{github})"

    full_author_str = name
    if github and email:
        full_author_str = f"{name} (@{github} <{email}>)"
    elif github:
        full_author_str = f"{name} (@{github})"
    elif email:
        full_author_str = f"{name} <{email}>"

    return {
        "name": name,
        "email": email,
        "github": github,
        "assignee": assignee_str,
        "full_author": full_author_str,
    }


def parse_tasks(planning_content: str):
    """Parse populated task rows from PLANNING.md."""
    task_pattern = re.compile(
        r"^\|\s*(?:\*\*)?([A-Za-z0-9\-_\.]+)(?:\*\*)?\s*\|\s*([^|]*)\|\s*([^|]*)\|\s*\[([ x\-])\]\s*([A-Za-z_]+)\s*\|\s*([^|]*)\|\s*([^|]*)\|",
        re.MULTILINE,
    )
    tasks = []
    for match in task_pattern.finditer(planning_content):
        task_id = match.group(1).strip()
        component = match.group(2).strip()
        description = match.group(3).strip()
        check_mark = match.group(4)
        status_word = match.group(5).strip()
        assignee = match.group(6).strip()
        completed_date = match.group(7).strip()

        tasks.append({
            "id": task_id,
            "component": component,
            "description": description,
            "status": f"[{check_mark}] {status_word}",
            "raw_status": status_word,
            "assignee": assignee,
            "completed_date": completed_date,
            "span": match.span(),
        })
    return tasks


def update_progress_summary(repo_root: Path, tasks: list):
    """Update the Progress Summary table in PROGRESS.md."""
    progress_file = repo_root / "PROGRESS.md"
    if not progress_file.exists():
        return

    content = progress_file.read_text(encoding="utf-8")

    total = len(tasks)
    done = sum(1 for t in tasks if "DONE" in t["status"])
    in_prog = sum(1 for t in tasks if "IN_PROGRESS" in t["status"])
    pending = sum(1 for t in tasks if "TODO" in t["status"])
    pct = int((done / total * 100)) if total > 0 else 0

    status_str = "Not Started"
    if total > 0:
        if done == total:
            status_str = "Completed (100%)"
        elif done > 0 or in_prog > 0:
            status_str = f"In Progress ({pct}%)"
        else:
            status_str = "Planned"

    # Update summary table row
    summary_regex = re.compile(
        r"(\|\s*Tasks\s*\|)\s*\d+\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*[^|]+\s*\|"
    )
    new_summary_row = f"\\1 {total} | {done} | {in_prog} | {pending} | {status_str} |"
    content = summary_regex.sub(new_summary_row, content)

    # Optional milestone-based updates if groupmates define milestones (M1, M2...)
    milestone_names = re.findall(r"\|\s*\*\*([A-Za-z0-9\s]+)\*\*\s*\|", content)
    for m_name in milestone_names:
        m_match = re.search(r"(\d+)", m_name)
        if m_match:
            prefix = f"M{m_match.group(1)}"
            m_tasks = [t for t in tasks if t["id"].startswith(prefix)]
            m_total = len(m_tasks)
            m_done = sum(1 for t in m_tasks if "DONE" in t["status"])
            m_in_prog = sum(1 for t in m_tasks if "IN_PROGRESS" in t["status"])
            m_pending = sum(1 for t in m_tasks if "TODO" in t["status"])
            m_pct = int((m_done / m_total * 100)) if m_total > 0 else 0
            m_status = "Not Started" if m_total == 0 else (
                "Completed (100%)" if m_done == m_total else f"In Progress ({m_pct}%)"
            )
            row_regex = re.compile(
                rf"(\|\s*\*\*{re.escape(m_name)}\*\*\s*\|\s*[^|]+\s*\|)\s*\d+\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*[^|]+\s*\|"
            )
            content = row_regex.sub(
                f"\\1 {m_total} | {m_done} | {m_in_prog} | {m_pending} | {m_status} |",
                content,
            )

    progress_file.write_text(content, encoding="utf-8")


def cmd_list(repo_root: Path):
    """List tasks in PLANNING.md."""
    planning_file = repo_root / "PLANNING.md"
    if not planning_file.exists():
        print(f"Error: {planning_file} not found.")
        sys.exit(1)

    content = planning_file.read_text(encoding="utf-8")
    tasks = parse_tasks(content)
    if not tasks:
        print("\nPLANNING.md currently has empty tables ready for your team to add tasks.")
        print("To add tasks, edit PLANNING.md and fill in Task ID, Component, and Description.")
        print("Example row: | TASK-01 | Mobile | Setup offline database | [ ] TODO | | |\n")
        return

    print(f"\nFound {len(tasks)} tasks in PLANNING.md:\n")
    print(f"{'Task ID':<12} {'Status':<16} {'Assignee':<26} {'Description'}")
    print("-" * 80)
    for t in tasks:
        assignee = t["assignee"] if t["assignee"] else "(unassigned)"
        print(f"{t['id']:<12} {t['status']:<16} {assignee:<26} {t['description']}")
    print()


def cmd_start(repo_root: Path, task_id: str):
    """Mark a task as IN_PROGRESS and assign to current user."""
    planning_file = repo_root / "PLANNING.md"
    if not planning_file.exists():
        print(f"Error: {planning_file} not found.")
        sys.exit(1)

    content = planning_file.read_text(encoding="utf-8")
    contributor = get_contributor_info()

    row_pattern = re.compile(
        rf"^(\|\s*(?:\*\*)?{re.escape(task_id)}(?:\*\*)?\s*\|\s*[^|]+\s*\|\s*[^|]+\s*\|)\s*\[[ x\-]\]\s*[A-Za-z_]+\s*\|\s*([^|]*)\|\s*([^|]*)\|",
        re.MULTILINE,
    )

    match = row_pattern.search(content)
    if not match:
        print(f"Task '{task_id}' not found in PLANNING.md.")
        sys.exit(1)

    existing_assignee = match.group(2).strip()
    assignee = existing_assignee if existing_assignee else contributor["assignee"]
    existing_date = match.group(3).strip()

    new_row = f"{match.group(1)} [-] IN_PROGRESS | {assignee} | {existing_date} |"
    new_content = row_pattern.sub(new_row, content, count=1)

    planning_file.write_text(new_content, encoding="utf-8")
    tasks = parse_tasks(new_content)
    update_progress_summary(repo_root, tasks)

    print(f"Task {task_id} marked as [-] IN_PROGRESS.")
    print(f"Assignee: {assignee}")


def cmd_done(repo_root: Path, task_id: str, notes: str = ""):
    """Mark a task as DONE, record Git contributor, and append to PROGRESS.md."""
    planning_file = repo_root / "PLANNING.md"
    progress_file = repo_root / "PROGRESS.md"

    if not planning_file.exists():
        print(f"Error: {planning_file} not found.")
        sys.exit(1)

    content = planning_file.read_text(encoding="utf-8")
    contributor = get_contributor_info()
    today_str = datetime.date.today().isoformat()

    row_pattern = re.compile(
        rf"^(\|\s*(?:\*\*)?{re.escape(task_id)}(?:\*\*)?\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|)\s*\[[ x\-]\]\s*[A-Za-z_]+\s*\|\s*([^|]*)\|\s*([^|]*)\|",
        re.MULTILINE,
    )

    match = row_pattern.search(content)
    if not match:
        print(f"Task '{task_id}' not found in PLANNING.md.")
        sys.exit(1)

    prefix = match.group(1)
    component = match.group(2).strip()
    description = match.group(3).strip()
    existing_assignee = match.group(4).strip()
    assignee = existing_assignee if existing_assignee else contributor["assignee"]

    new_row = f"{prefix} [x] DONE | {assignee} | {today_str} |"
    new_content = row_pattern.sub(new_row, content, count=1)
    planning_file.write_text(new_content, encoding="utf-8")

    # Update PROGRESS.md
    if progress_file.exists():
        prog_content = progress_file.read_text(encoding="utf-8")
        # Remove placeholder comment if present
        placeholder = "*(No activity logged yet. Completed tasks will be recorded here automatically when marked done via the tracker.)*"
        if placeholder in prog_content:
            prog_content = prog_content.replace(placeholder, "").strip() + "\n"

        entry_notes = notes.strip() if notes else f"Completed task {task_id}: {description}"

        entry = f"\n### [{today_str}] {task_id}: {description}\n"
        entry += f"- **Status**: [x] DONE\n"
        entry += f"- **Contributor**: {contributor['full_author']}\n"
        if component:
            entry += f"- **Component**: {component}\n"
        entry += f"- **Summary**: {entry_notes}\n"

        if "## Activity Log" in prog_content:
            parts = prog_content.split("## Activity Log", 1)
            new_prog_content = parts[0] + "## Activity Log\n" + entry + parts[1]
        else:
            new_prog_content = prog_content + "\n## Activity Log\n" + entry

        progress_file.write_text(new_prog_content, encoding="utf-8")

    # Update summary table
    tasks = parse_tasks(new_content)
    update_progress_summary(repo_root, tasks)

    print(f"Task {task_id} successfully marked as [x] DONE!")
    print(f"Contributor: {contributor['full_author']}")
    print(f"Date: {today_str}")
    if notes:
        print(f"Notes: {notes}")
    print(f"Updated {planning_file.name} and {progress_file.name}.")


def main():
    parser = argparse.ArgumentParser(description="Wayday Task Tracker CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # list
    subparsers.add_parser("list", help="List all tasks and statuses")

    # start
    start_parser = subparsers.add_parser("start", help="Mark a task as IN_PROGRESS")
    start_parser.add_argument("task_id", help="Task ID (e.g. TASK-01)")

    # done
    done_parser = subparsers.add_parser("done", help="Mark a task as DONE")
    done_parser.add_argument("task_id", help="Task ID (e.g. TASK-01)")
    done_parser.add_argument("--notes", "-n", default="", help="Summary or verification notes")

    args = parser.parse_args()
    repo_root = get_repo_root()

    if args.command == "list":
        cmd_list(repo_root)
    elif args.command == "start":
        cmd_start(repo_root, args.task_id)
    elif args.command == "done":
        cmd_done(repo_root, args.task_id, args.notes)


if __name__ == "__main__":
    main()
