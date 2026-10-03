#!/usr/bin/env python3
"""Append-only shared state prototype for a user-selected DriveFS folder."""
import json
import os
import sys
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path


PREFERENCES = {"sound": {"on", "off"}, "recommendations": {"on", "off"}}
STATUSES = {"todo", "in_progress", "done"}


def fail(message):
    print(message, file=sys.stderr)
    return 2


def valid_key(key):
    if not isinstance(key, str):
        return False
    if key in PREFERENCES:
        return True
    if key.startswith("work."):
        try:
            return str(uuid.UUID(key[5:])) == key[5:]
        except ValueError:
            return False
    return False


def valid_key_value(key, value):
    if not valid_key(key) or not isinstance(value, str):
        return False
    allowed = PREFERENCES[key] if key in PREFERENCES else STATUSES
    return value in allowed


def read_latest(events):
    latest = {}
    try:
        paths = sorted(path for path in events.iterdir() if path.suffix == ".json") if events.exists() else []
    except OSError as exc:
        raise RuntimeError(f"Shared state unavailable: {exc}") from exc
    for path in paths:
        try:
            event = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(event, dict) or event.get("schema_version") != 1:
                continue
            key, value = event.get("key"), event.get("value")
            event_id, updated = event.get("event_id"), event.get("updated_at")
            try:
                event_uuid = uuid.UUID(event_id)
                event_time = datetime.fromisoformat(updated)
                version = event.get("logical_version")
                if event_time.tzinfo is None:
                    continue
                if version is not None and (isinstance(version, bool) or not isinstance(version, int) or version < 1):
                    continue
            except (ValueError, TypeError):
                continue
            if str(event_uuid) != event_id or event_uuid.hex != path.stem.replace("-", "") or not valid_key_value(key, value):
                continue
            # Preserve timestamp ordering for pre-logical-version events. Once
            # a key has a logical version, it supersedes every legacy event.
            candidate = (1, version, event_id, value) if version is not None else (0, event_time.timestamp(), event_id, value)
            if key not in latest or candidate[:3] > latest[key][:3]:
                latest[key] = candidate
        except (OSError, ValueError, TypeError):
            continue
    return latest


def main(args):
    root = os.environ.get("CHATGPT_ALERT_SHARED_STATE_DIR")
    if not root:
        return fail("Set CHATGPT_ALERT_SHARED_STATE_DIR to the Drive for Desktop state-v1 folder.")
    state_root = Path(root).expanduser()
    if not state_root.is_dir():
        return fail("Shared Drive state folder is unavailable or not a directory.")
    events = state_root / "events"
    if args == ["list"] or (len(args) == 2 and args[0] == "get"):
        requested_key = args[1] if len(args) == 2 else None
        try:
            latest = read_latest(events)
        except RuntimeError as exc:
            return fail(str(exc))
        if requested_key is not None:
            if not valid_key(requested_key):
                return fail("Unknown shared-state key.")
            if requested_key in latest:
                print(latest[requested_key][3])
            return 0
        print(json.dumps({key: row[3] for key, row in sorted(latest.items())}, sort_keys=True))
        return 0
    if len(args) == 3 and args[0] == "set":
        _, key, value = args
        if not valid_key_value(key, value):
            return fail("Allowed: sound|recommendations on|off, or work.<UUID> todo|in_progress|done.")
        temp_path = None
        try:
            events.mkdir(exist_ok=True)
            latest = read_latest(events)
            event_id = str(uuid.uuid4())
            event = {
                "schema_version": 1,
                "event_id": event_id,
                "key": key,
                "value": value,
                "logical_version": latest.get(key, (0, 0, "", ""))[1] + 1 if latest.get(key, (0, 0, "", ""))[0] == 1 else 1,
                "updated_at": datetime.now(timezone.utc).isoformat(timespec="microseconds"),
            }
            # Stage the complete event before atomically exposing its final name.
            fd, temp_path = tempfile.mkstemp(prefix=f".{event_id}.", suffix=".tmp", dir=events)
            with os.fdopen(fd, "w", encoding="utf-8") as output:
                json.dump(event, output, separators=(",", ":"))
                output.write("\n")
                output.flush()
                os.fsync(output.fileno())
            os.rename(temp_path, events / f"{event_id}.json")
            print(event_id)
            return 0
        except OSError as exc:
            if temp_path:
                try:
                    Path(temp_path).unlink(missing_ok=True)
                except OSError:
                    pass
            return fail(f"Shared-state write failed: {exc}")
        except RuntimeError as exc:
            return fail(str(exc))
    return fail("Usage: drive-state.py list | get <key> | set <sound|recommendations|work.UUID> <value>")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
