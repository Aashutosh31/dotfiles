#!/usr/bin/env python3
"""Private local task storage and due notifications for the Task Coach plugin."""

from __future__ import annotations

import fcntl
import html
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from contextlib import contextmanager
from pathlib import Path

MAX_TASKS = 2000
MAX_TITLE = 160
PRIORITIES = {"low", "medium", "high"}
ID_RE = re.compile(r"^[0-9a-f]{32}$")
DATA_HOME = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
DATA_DIR = DATA_HOME / "omarchy-task-coach"
DATA_FILE = DATA_DIR / "tasks.json"
LOCK_FILE = DATA_DIR / "tasks.lock"


def _prepare_dir() -> None:
    DATA_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(DATA_DIR, 0o700)


@contextmanager
def _locked():
    _prepare_dir()
    fd = os.open(LOCK_FILE, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        with os.fdopen(fd, "r+") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            yield
    finally:
        pass


def _load_unlocked() -> list[dict]:
    try:
        raw = DATA_FILE.read_text(encoding="utf-8")
        if len(raw) > 2_000_000:
            raise ValueError("Task file exceeds the safe size limit; it was not changed.")
        doc = json.loads(raw)
        if not isinstance(doc, dict) or doc.get("version") != 1:
            raise ValueError("Task file has an unsupported format; it was not changed.")
        tasks = doc.get("tasks")
        if not isinstance(tasks, list) or len(tasks) > MAX_TASKS:
            raise ValueError("Task file is malformed; it was not changed.")
        valid = []
        for row in tasks:
            if not isinstance(row, dict):
                raise ValueError("Task file contains invalid data; it was not changed.")
            task_id = row.get("id")
            title = row.get("title")
            priority = row.get("priority")
            due = row.get("due")
            if (
                not isinstance(task_id, str)
                or not ID_RE.fullmatch(task_id)
                or not isinstance(title, str)
                or not title.strip()
                or len(title) > MAX_TITLE
                or priority not in PRIORITIES
                or type(due) not in (int, float)
                or not math.isfinite(due)
            ):
                raise ValueError("Task file contains invalid data; it was not changed.")
            valid.append({
                "id": task_id,
                "title": title,
                "priority": priority,
                "due": float(due),
                "done": row.get("done") is True,
                "notified": row.get("notified") is True,
                "laterCount": max(0, int(row.get("laterCount", 0))),
            })
        return valid
    except FileNotFoundError:
        return []
    except (UnicodeError, json.JSONDecodeError) as error:
        raise ValueError("Task file is unreadable; it was not changed.") from error


def _save_unlocked(tasks: list[dict]) -> None:
    _prepare_dir()
    payload = json.dumps({"version": 1, "tasks": tasks}, ensure_ascii=False, indent=2) + "\n"
    fd, temp_path = tempfile.mkstemp(prefix=".tasks-", dir=DATA_DIR)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as temp:
            temp.write(payload)
            temp.flush()
            os.fsync(temp.fileno())
        os.replace(temp_path, DATA_FILE)
        dir_fd = os.open(DATA_DIR, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
        try:
            os.fsync(dir_fd)
        finally:
            os.close(dir_fd)
    finally:
        try:
            os.unlink(temp_path)
        except FileNotFoundError:
            pass


def tasks_list() -> list[dict]:
    with _locked():
        tasks = _load_unlocked()
        remaining = [task for task in tasks if not (task["done"] and task["due"] <= time.time())]
        if len(remaining) != len(tasks):
            _save_unlocked(remaining)
            tasks = remaining
    return sorted(tasks, key=lambda t: (t["done"], t["due"], {"high": 0, "medium": 1, "low": 2}[t["priority"]]))


def add_task(title: str, priority: str, due: str) -> dict:
    title = title.strip()
    if not title or len(title) > MAX_TITLE:
        raise ValueError(f"Title must be 1–{MAX_TITLE} characters.")
    if priority not in PRIORITIES:
        raise ValueError("Priority must be low, medium, or high.")
    due_at = float(due)
    if not math.isfinite(due_at) or due_at < time.time() - 60:
        raise ValueError("Choose a due time in the future.")
    with _locked():
        tasks = _load_unlocked()
        if len(tasks) >= MAX_TASKS:
            raise ValueError("Task limit reached.")
        task = {
            "id": uuid.uuid4().hex,
            "title": title,
            "priority": priority,
            "due": due_at,
            "done": False,
            "notified": False,
            "laterCount": 0,
        }
        tasks.append(task)
        _save_unlocked(tasks)
    return task


def update_task(
    task_id: str,
    action: str,
    due: str | None = None,
    title: str | None = None,
    priority: str | None = None,
) -> None:
    if not ID_RE.fullmatch(task_id):
        raise ValueError("Invalid task id.")
    completed_title = None
    roast = None
    with _locked():
        tasks = _load_unlocked()
        task = next((t for t in tasks if t["id"] == task_id), None)
        if task is None:
            return
        if action == "done":
            if not task["done"]:
                completed_title = task["title"]
            if task["due"] <= time.time():
                tasks.remove(task)
            else:
                task["done"] = True
                task["notified"] = False
        elif action == "undo":
            task["done"] = False
            task["notified"] = False
        elif action in {"snooze", "later"}:
            delay = float(due) if due is not None else 15 * 60
            if not math.isfinite(delay) or delay < 60 or delay > 365 * 24 * 60 * 60:
                raise ValueError("Choose a delay between 1 minute and 1 year.")
            task["due"] = time.time() + delay
            task["notified"] = False
            task["done"] = False
            task["laterCount"] += 1
            roast = (task["title"], task["laterCount"])
        elif action == "not-done":
            task["notified"] = True
            roast = (task["title"], task["laterCount"])
        elif action == "reschedule":
            if due is None:
                raise ValueError("A due timestamp is required.")
            new_due = float(due)
            if not math.isfinite(new_due) or new_due <= time.time():
                raise ValueError("Choose a due time in the future.")
            task["due"] = new_due
            task["notified"] = False
        elif action == "edit":
            if title is None or priority not in PRIORITIES or due is None:
                raise ValueError("Title, priority, and due time are required.")
            title = title.strip()
            new_due = float(due)
            if not title or len(title) > MAX_TITLE or not math.isfinite(new_due):
                raise ValueError("Invalid task details.")
            task["title"] = title
            task["priority"] = priority
            task["due"] = new_due
            task["notified"] = False
        elif action == "delete":
            tasks.remove(task)
        else:
            raise ValueError("Unknown task action.")
        _save_unlocked(tasks)
    if roast is not None:
        title, later_count = roast
        headline = "Not done? At least you're honest."
        body = f"The task is still waiting. Make a plan—or finish it now. {html.escape(title, quote=True)}"
        if later_count == 1:
            headline = "That excuse is on the record."
            body = f"You've postponed this once. Pick a time you can actually keep. {html.escape(title, quote=True)}"
        elif later_count == 2:
            headline = "Postponed twice. The bot noticed."
            body = f"One more 'later' and the roast gets upgraded. {html.escape(title, quote=True)}"
        elif later_count >= 3:
            headline = "The snooze button is doing all the work."
            body = f"You've delayed this {later_count} times. Give it a real slot—or finish it now."
        try:
            subprocess.run(
                [
                    "omarchy", "notification", "send",
                    "--app-name", "Task Coach",
                    "-g", "󰀠",
                    headline,
                    body,
                ],
                check=False,
                timeout=8,
                capture_output=True,
            )
        except (OSError, subprocess.TimeoutExpired):
            pass
    if completed_title is not None:
        try:
            subprocess.run(
                [
                    "omarchy", "notification", "send",
                    "--app-name", "Task Coach",
                    "-g", "󰀠",
                    "You did the thing. Look at you proving the bot wrong.",
                    html.escape(completed_title, quote=True),
                ],
                check=False,
                timeout=8,
                capture_output=True,
            )
        except (OSError, subprocess.TimeoutExpired):
            pass


def notify_due() -> int:
    """Notify once per due task; successful sends are recorded atomically."""
    sent = 0
    failures = 0
    now = time.time()
    with _locked():
        tasks = _load_unlocked()
        retained = [task for task in tasks if not (task["done"] and task["due"] <= now)]
        changed = len(retained) != len(tasks)
        tasks = retained
        due_tasks = [t for t in tasks if not t["done"] and not t["notified"] and t["due"] <= now]
        script = str(Path(__file__).resolve())
        for task in due_tasks:
            title = html.escape(task["title"], quote=True)
            count = task["laterCount"]
            headline = f"Did you finish this? {title}"
            description = "Be honest: done, not done, or choose a new time."
            if count >= 3:
                headline = f"Postponement #{count}: {title}"
                description = "The snooze button is getting more use than the task. Time to make a real choice."
            argv = [
                "omarchy", "notification", "send",
                # Omarchy's quiet-mode policy only lets its action channel
                # through, which is important for deadline reminders.
                "--app-name", "omarchy-action",
                # Critical notifications remain on screen until the user acts.
                "-u", "critical",
                "-g", "󰀠",
                headline,
                description,
                "--action", "Yes, done", "omarchy-shell", "-q",
                "aashutosh31.taskcoach", "done", task["id"],
                "--action", "Not yet", sys.executable, script, "not-done", task["id"],
                "--action", "Later · 30 min", "omarchy-shell", "-q",
                "aashutosh31.taskcoach", "snooze30", task["id"],
            ]
            try:
                result = subprocess.run(argv, check=False, timeout=8, capture_output=True)
            except (OSError, subprocess.TimeoutExpired):
                failures += 1
                continue
            if result.returncode == 0:
                task["notified"] = True
                sent += 1
                changed = True
            else:
                failures += 1
        if changed:
            _save_unlocked(tasks)
    if failures:
        raise RuntimeError(
            f"Could not deliver {failures} due reminder(s); they will be retried."
        )
    if sent:
        _play_reminder_sound()
    return sent


def _play_reminder_sound() -> None:
    """Play a short sound-theme cue without making audio a delivery dependency."""
    if os.environ.get("TASKCOACH_SOUND", "1") != "1":
        return
    player = shutil.which("canberra-gtk-play")
    if player is None:
        return
    try:
        subprocess.run(
            [player, "--id=message-new-instant", "--description=Task Coach reminder"],
            check=False,
            timeout=3,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.TimeoutExpired):
        pass


def main(argv: list[str]) -> int:
    try:
        command = argv[0] if argv else "list"
        if command == "list":
            print(json.dumps(tasks_list(), ensure_ascii=False))
        elif command == "add" and len(argv) == 4:
            print(json.dumps(add_task(argv[1], argv[2], argv[3]), ensure_ascii=False))
        elif command in {"done", "undo", "delete", "not-done"} and len(argv) == 2:
            update_task(argv[1], command)
        elif command in {"snooze", "later"} and len(argv) in {2, 3}:
            delay = argv[2] if len(argv) == 3 else None
            update_task(argv[1], command, delay)
        elif command == "edit" and len(argv) == 5:
            update_task(argv[1], command, argv[4], argv[2], argv[3])
        elif command == "reschedule" and len(argv) == 3:
            update_task(argv[1], command, argv[2])
        elif command == "notify-due" and len(argv) == 1:
            notify_due()
        else:
            raise ValueError("Invalid command.")
        return 0
    except (ValueError, OSError, RuntimeError) as error:
        print(str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
