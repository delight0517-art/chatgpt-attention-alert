#!/usr/bin/env python3
"""Small stdlib smoke checks for the Mac Drive state event log."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "plugin/companion/macos/drive-state.py"
KEY = "work.550e8400-e29b-41d4-a716-446655440000"


class DriveStateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state = Path(self.temp.name) / "state-v1"
        self.env = {**os.environ, "CHATGPT_ALERT_SHARED_STATE_DIR": str(self.state)}

    def run_cli(self, *args, configured=True):
        env = self.env if configured else {k: v for k, v in os.environ.items() if k != "CHATGPT_ALERT_SHARED_STATE_DIR"}
        return subprocess.run([sys.executable, str(SCRIPT), *args], env=env, text=True, capture_output=True)

    def test_allowlisted_updates_are_append_only_and_readable(self):
        self.assertEqual(self.run_cli("set", "sound", "off").returncode, 0)
        self.assertEqual(self.run_cli("set", "sound", "on").returncode, 0)
        self.assertEqual(self.run_cli("set", KEY, "in_progress").returncode, 0)
        result = self.run_cli("list")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {"sound": "on", KEY: "in_progress"})
        self.assertEqual(len(list((self.state / "events").glob("*.json"))), 3)

    def test_newest_timestamp_wins_and_uuid_breaks_ties(self):
        events = self.state / "events"
        events.mkdir(parents=True)
        fixtures = [
            {"schema_version": 1, "event_id": "b", "key": "sound", "value": "off", "updated_at": "2026-01-01T00:00:00+00:00"},
            {"schema_version": 1, "event_id": "a", "key": "sound", "value": "on", "updated_at": "2026-01-01T00:00:00+00:00"},
            {"schema_version": 1, "event_id": "c", "key": "sound", "value": "off", "updated_at": "2025-12-31T23:59:59+00:00"},
        ]
        for event in fixtures:
            (events / f"{event['event_id']}.json").write_text(json.dumps(event), encoding="utf-8")
        result = self.run_cli("list")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {"sound": "off"})

    def test_invalid_updates_and_unconfigured_state_are_rejected(self):
        self.assertNotEqual(self.run_cli("set", "sound", "maybe").returncode, 0)
        self.assertNotEqual(self.run_cli("set", "work.student-name", "done").returncode, 0)
        missing = self.run_cli("list", configured=False)
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("CHATGPT_ALERT_SHARED_STATE_DIR", missing.stderr)

    def test_unknown_or_corrupt_events_are_ignored(self):
        events = self.state / "events"
        events.mkdir(parents=True)
        (events / "bad.json").write_text("not json", encoding="utf-8")
        (events / "unknown.json").write_text(json.dumps({"schema_version": 99}), encoding="utf-8")
        result = self.run_cli("list")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {})


if __name__ == "__main__":
    unittest.main()
