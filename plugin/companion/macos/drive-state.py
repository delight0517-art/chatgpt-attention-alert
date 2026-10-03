#!/usr/bin/env python3
"""Append-only shared state prototype for a user-selected DriveFS folder."""
import json
import os
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path


PREFERENCES = {"sound": {"on", "off"}, "recommendations": {"on", "off"}}
STATUSES = {"todo", "in_progress", "done"}


def fail(message):
    print(message, file=sys.stderr)
    return 2


def valid_key_value(key, value):
    if key in PREFERENCES:
        return value in PREFERENCES[key]
    if key.startswith("work.") and key[5:]:
        try:
            uuid.UUID(key[5:])
        except ValueError:
            return False
        return value in STATUSES
    return False


def main(args):
    root = os.environ.get("CHATGPT_ALERT_SHARED_STATE_DIR")
    if not root:
        return fail("Set CHATGPT_ALERT_SHARED_STATE_DIR to the Drive for Desktop state-v1 folder.")
    events = Path(root).expanduser() / "events"
    if args == ["list"]:
        latest = {}
        try:
            paths = sorted(events.glob("*.json"))
        except OSError as exc:
            return fail(f"Shared state unavailable: {exc}")
        for path in paths:
            try:
                event = json.loads(path.read_text(encoding="utf-8"))
                if event.get("schema_version") != 1:
                    continue
                key, value = event.get("key"), event.get("value")
                event_id = event.get("event_id")
                updated = event.get("updated_at")
                if not isinstance(event_id, str) or not isinstance(updated, str) or not valid_key_value(key, value):
                    continue
                candidate = (updated, event_id, value)
                if key not in latest or candidate[:2] > latest[key][:2]:
                    latest[key] = candidate
            except (OSError, ValueError, TypeError):
                continue
        print(json.dumps({key: row[2] for key, row in sorted(latest.items())}, sort_keys=True))
        return 0
    if len(args) == 3 and args[0] == "set":
        _, key, value = args
        if not valid_key_value(key, value):
            return fail("Allowed: sound|recommendations on|off, or work.<UUID> todo|in_progress|done.")
        try:
            events.mkdir(parents=True, exist_ok=True)
            event_id = str(uuid.uuid4())
            event = {
                "schema_version": 1,
                "event_id": event_id,
                "key": key,
                "value": value,
                "updated_at": datetime.now(timezone.utc).isoformat(timespec="microseconds"),
            }
            # O_EXCL prevents an event collision or accidental replacement.
            fd = os.open(events / f"{event_id}.json", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as output:
                json.dump(event, output, separators=(",", ":"))
                output.write("\n")
                output.flush()
                os.fsync(output.fileno())
            print(event_id)
            return 0
        except OSError as exc:
            return fail(f"Shared state unavailable; local settings were not changed: {exc}")
    return fail("Usage: drive-state.py list | set <sound|recommendations|work.UUID> <value>")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
