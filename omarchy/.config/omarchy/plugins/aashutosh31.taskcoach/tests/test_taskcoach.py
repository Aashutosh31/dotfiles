import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "taskcoach.py"


class TaskCoachStorageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        fake_bin = Path(self.temp.name) / "bin"
        fake_bin.mkdir()
        fake_omarchy = fake_bin / "omarchy"
        log_path = Path(self.temp.name) / "notifications.log"
        fake_omarchy.write_text(
            '#!/bin/sh\nprintf "%s\\n" "$*" >> "$TASKCOACH_NOTIFICATION_LOG"\n'
            '[ "${TASKCOACH_FAIL_NOTIFICATION:-0}" = 1 ] && exit 1\nexit 0\n',
            encoding="utf-8",
        )
        fake_omarchy.chmod(0o700)
        self.env = {
            **os.environ,
            "XDG_DATA_HOME": self.temp.name,
            "TASKCOACH_SOUND": "0",
            "PATH": str(fake_bin) + os.pathsep + os.environ["PATH"],
            "TASKCOACH_NOTIFICATION_LOG": str(log_path),
        }
        self.notification_log = log_path

    def tearDown(self):
        self.temp.cleanup()

    def run_cli(self, *args, check=True):
        return subprocess.run(
            [sys.executable, str(SCRIPT), *map(str, args)],
            env=self.env,
            capture_output=True,
            text=True,
            check=check,
        )

    def test_add_complete_undo_and_reschedule(self):
        task = json.loads(self.run_cli("add", "Ship the tiny win", "high", "4102444800").stdout)
        self.assertEqual(task["priority"], "high")

        listing = json.loads(self.run_cli("list").stdout)
        self.assertEqual(listing[0]["title"], "Ship the tiny win")
        self.run_cli("done", task["id"])
        self.assertTrue(json.loads(self.run_cli("list").stdout)[0]["done"])
        self.run_cli("undo", task["id"])
        self.run_cli("reschedule", task["id"], "4102444801")
        saved = json.loads(self.run_cli("list").stdout)[0]
        self.assertFalse(saved["done"])
        self.assertEqual(saved["due"], 4102444801)

    def test_rejects_invalid_priority_and_bad_id(self):
        invalid = self.run_cli("add", "Bad priority", "urgent", "4102444800", check=False)
        self.assertNotEqual(invalid.returncode, 0)
        invalid = self.run_cli("done", "../../outside", check=False)
        self.assertNotEqual(invalid.returncode, 0)

    def test_markup_remains_plain_task_text(self):
        title = '<img src="https://example.invalid/tracker">'
        self.run_cli("add", title, "medium", "4102444800")
        self.assertEqual(json.loads(self.run_cli("list").stdout)[0]["title"], title)

    def test_private_file_permissions(self):
        self.run_cli("add", "Private", "low", "4102444800")
        data_dir = Path(self.temp.name) / "omarchy-task-coach"
        self.assertEqual(data_dir.stat().st_mode & 0o777, 0o700)
        self.assertEqual((data_dir / "tasks.json").stat().st_mode & 0o777, 0o600)

    def test_corrupt_file_is_not_overwritten(self):
        data_dir = Path(self.temp.name) / "omarchy-task-coach"
        data_dir.mkdir(mode=0o700)
        data_file = data_dir / "tasks.json"
        data_file.write_text("{not json", encoding="utf-8")
        result = self.run_cli("add", "Keep original", "low", "4102444800", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(data_file.read_text(encoding="utf-8"), "{not json")

    def test_due_notification_is_sent_only_once(self):
        data_dir = Path(self.temp.name) / "omarchy-task-coach"
        data_dir.mkdir(mode=0o700)
        data_file = data_dir / "tasks.json"
        data_file.write_text(
            json.dumps({
                "version": 1,
                "tasks": [{
                    "id": "a" * 32,
                    "title": "Past due task",
                    "priority": "medium",
                    # Simulate a reminder whose deadline passed while the
                    # machine was asleep for an hour.
                    "due": time.time() - 3600,
                    "done": False,
                    "notified": False,
                }],
            }),
            encoding="utf-8",
        )
        self.run_cli("notify-due")
        self.run_cli("notify-due")
        self.assertEqual(len(self.notification_log.read_text().splitlines()), 1)
        self.assertTrue(json.loads(self.run_cli("list").stdout)[0]["notified"])
        notification = self.notification_log.read_text()
        self.assertIn("--app-name omarchy-action", notification)
        self.assertIn("-u critical", notification)
        self.assertIn("Yes, done omarchy-shell -q aashutosh31.taskcoach done", notification)
        self.assertIn("Not yet", notification)
        self.assertIn("Later · 30 min omarchy-shell -q aashutosh31.taskcoach snooze30", notification)

    def test_failed_due_notification_is_not_marked_sent_and_retries(self):
        data_dir = Path(self.temp.name) / "omarchy-task-coach"
        data_dir.mkdir(mode=0o700)
        (data_dir / "tasks.json").write_text(
            json.dumps({
                "version": 1,
                "tasks": [{
                    "id": "d" * 32,
                    "title": "Retry this reminder",
                    "priority": "medium",
                    "due": 1,
                    "done": False,
                    "notified": False,
                }],
            }),
            encoding="utf-8",
        )
        failed_env = {**self.env, "TASKCOACH_FAIL_NOTIFICATION": "1"}
        failed = subprocess.run(
            [sys.executable, str(SCRIPT), "notify-due"],
            env=failed_env,
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn("will be retried", failed.stderr)
        self.assertFalse(json.loads(self.run_cli("list").stdout)[0]["notified"])
        self.run_cli("notify-due")
        self.assertTrue(json.loads(self.run_cli("list").stdout)[0]["notified"])

    def test_not_done_action_roasts_without_rescheduling(self):
        task = json.loads(self.run_cli("add", "Finish the draft", "medium", "4102444800").stdout)
        self.run_cli("not-done", task["id"])
        saved = json.loads(self.run_cli("list").stdout)[0]
        self.assertTrue(saved["notified"])
        self.assertEqual(saved["laterCount"], 0)
        self.assertIn("Not done? At least you're honest", self.notification_log.read_text())

    def test_later_tracks_uses_and_escalates_after_two(self):
        task = json.loads(self.run_cli("add", "Write the report", "high", "4102444800").stdout)
        for expected in (1, 2, 3):
            before = time.time()
            self.run_cli("later", task["id"], "900")
            saved = json.loads(self.run_cli("list").stdout)[0]
            self.assertEqual(saved["laterCount"], expected)
            self.assertGreaterEqual(saved["due"], before + 900)
        self.assertIn("snooze button is doing all the work", self.notification_log.read_text())

    def test_done_overdue_task_is_removed(self):
        data_dir = Path(self.temp.name) / "omarchy-task-coach"
        data_dir.mkdir(mode=0o700)
        (data_dir / "tasks.json").write_text(
            json.dumps({
                "version": 1,
                "tasks": [{
                    "id": "b" * 32,
                    "title": "Already overdue",
                    "priority": "medium",
                    "due": 1,
                    "done": False,
                    "notified": True,
                }],
            }),
            encoding="utf-8",
        )
        self.run_cli("done", "b" * 32)
        self.assertEqual(json.loads(self.run_cli("list").stdout), [])

    def test_completed_task_is_pruned_after_its_due_time(self):
        data_dir = Path(self.temp.name) / "omarchy-task-coach"
        data_dir.mkdir(mode=0o700)
        (data_dir / "tasks.json").write_text(
            json.dumps({
                "version": 1,
                "tasks": [{
                    "id": "c" * 32,
                    "title": "Finished early",
                    "priority": "low",
                    "due": 1,
                    "done": True,
                    "notified": False,
                }],
            }),
            encoding="utf-8",
        )
        self.assertEqual(json.loads(self.run_cli("list").stdout), [])

    def test_delete_removes_task(self):
        task = json.loads(self.run_cli("add", "Remove me", "low", "4102444800").stdout)
        self.run_cli("delete", task["id"])
        self.assertEqual(json.loads(self.run_cli("list").stdout), [])


if __name__ == "__main__":
    unittest.main()
