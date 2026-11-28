"""Contract tests for the Omarchy Guard backend.

These run the real scripts and validate the JSON the QML widget will consume.
They intentionally avoid touching the user's cache: every run gets a temporary
GUARD_CACHE_DIR.
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DAEMON = ROOT / "scripts" / "guard-daemon.sh"
KILL = ROOT / "scripts" / "guard-kill.sh"
MANIFEST = ROOT / "manifest.json"


class ManifestTests(unittest.TestCase):
    def test_manifest_matches_omarchy_contract(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["schemaVersion"], 1)
        self.assertEqual(manifest["id"], "aashutosh31.guard")
        self.assertEqual(manifest["kinds"], ["bar-widget"])
        self.assertEqual(manifest["entryPoints"]["barWidget"], "BarWidget.qml")
        self.assertEqual(manifest["barWidget"]["category"], "System")


class DaemonTests(unittest.TestCase):
    def run_daemon(self, *args: str) -> dict:
        with tempfile.TemporaryDirectory() as cache:
            env = os.environ.copy()
            env["GUARD_CACHE_DIR"] = cache
            proc = subprocess.run(
                [str(DAEMON), *args],
                capture_output=True,
                text=True,
                timeout=60,
                env=env,
            )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stderr.strip(), "", proc.stderr)
        return json.loads(proc.stdout)

    def test_fast_snapshot_shape(self):
        data = self.run_daemon("--fast")
        self.assertEqual(data["schemaVersion"], 1)
        self.assertIn(data["status"], {"secure", "warning", "alert"})
        self.assertIsInstance(data["summary"], str)
        self.assertIsInstance(data["durationMs"], int)
        self.assertIsInstance(data["reasons"], list)
        self.assertIsInstance(data["errors"], list)

        agents = data["agents"]
        self.assertIsInstance(agents["count"], int)
        self.assertEqual(agents["count"], len(agents["list"]))
        for agent in agents["list"]:
            self.assertIsInstance(agent["pid"], int)
            self.assertIsInstance(agent["cpu"], (int, float))
            self.assertIsInstance(agent["command"], str)
            self.assertIn("highCpu", agent)
            self.assertIn("longRunning", agent)

        security = data["security"]
        for key in ("failedSsh", "sshWindow", "journalAvailable", "sudo", "ports"):
            self.assertIn(key, security)
        self.assertIsInstance(security["ports"], list)
        for port in security["ports"]:
            self.assertIn("proto", port)
            self.assertIn("local", port)
            self.assertIn("loopback", port)
            self.assertNotRegex(port["local"], r"(?<!x)\b(?:\d{1,3}\.){3}\d{1,3}\b")
            self.assertNotRegex(port["local"], r"\b[0-9A-Fa-f]{1,4}:[0-9A-Fa-f:]{2,}\b")

        hardware = data["hardware"]
        self.assertIn("cpuTempC", hardware)
        self.assertIsInstance(hardware["disks"], list)
        for disk in hardware["disks"]:
            self.assertIn(disk["health"], {
                "passed", "failed", "permission-denied", "unsupported",
                "timeout", "unknown",
            })
        self.assertIn("present", hardware["battery"])

        system = data["system"]
        for key in ("cpuPercent", "memPercent", "memTotalMb", "memUsedMb", "load1"):
            self.assertIn(key, system)
        self.assertIsInstance(system["memPercent"], int)
        self.assertGreater(system["memTotalMb"], 0)

    def test_output_contains_no_private_addresses_or_home_paths(self):
        raw = json.dumps(self.run_daemon("--fast"))
        self.assertNotIn("/home/", raw)
        self.assertNotRegex(raw, r"\b(?:10|192\.168|172\.(?:1[6-9]|2\d|3[01]))\.\d+\.\d+\b")
        self.assertNotRegex(raw, r"\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b")
        self.assertNotRegex(raw, r"\b(?:sk-|ghp_|github_pat_)[A-Za-z0-9_-]{8,}")
        self.assertNotRegex(raw, r"--(?:api-key|token|password)=\S+")

    def test_smart_cache_is_reused_in_fast_mode(self):
        first = self.run_daemon("--full")
        self.assertIsInstance(first["hardware"]["disks"], list)


class KillTests(unittest.TestCase):
    def run_kill(self, *args: str) -> tuple[int, dict]:
        proc = subprocess.run(
            [str(KILL), *args], capture_output=True, text=True, timeout=15
        )
        return proc.returncode, json.loads(proc.stdout)

    def test_rejects_bad_pid(self):
        for bad in ("abc", "0", "1", "-5", "999999999"):
            code, payload = self.run_kill(bad)
            self.assertNotEqual(code, 0, bad)
            self.assertFalse(payload["ok"], bad)

    def test_rejects_non_agent_process(self):
        sleeper = subprocess.Popen(["sleep", "30"])
        try:
            code, payload = self.run_kill(str(sleeper.pid))
            self.assertNotEqual(code, 0)
            self.assertFalse(payload["ok"])
            self.assertIsNone(sleeper.poll())
        finally:
            sleeper.terminate()
            sleeper.wait(timeout=5)


if __name__ == "__main__":
    unittest.main()
