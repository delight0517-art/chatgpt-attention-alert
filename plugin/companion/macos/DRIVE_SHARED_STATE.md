# Shared Drive state (Mac-first proposal)

## Authority and location

GitHub `main` remains authoritative for app source. Google Drive for Desktop owns only shared, non-sensitive state in a user-selected folder, for example `Google Drive/My Drive/ChatGPTAttentionAlert/state-v1`. The Mac and Windows clients must point to the same folder. Do not use Drive API tokens or put credentials in this repository.

## Data and merge rules

Store one immutable JSON event per update under `events/<UUID>.json`. Events contain schema version, event UUID, logical key, allowlisted value, and UTC timestamp. The shared state is the latest valid event per key; ties are resolved by event UUID lexicographically. Concurrent edits therefore remain available and deterministic instead of overwriting one another. Invalid or unknown fields are ignored; clients never delete events. A later compaction must be opt-in and retain a recoverable backup.

The allowlist is intentionally limited to non-sensitive app preferences (`sound`, `recommendations`) and coarse user-authored work status with opaque UUIDs and enum values (`todo`, `in_progress`, `done`). Do not sync alert title/body/chat URL, login links, account names, student data, custom sound paths, recommendation history, or machine-local paths. Pause timers and stack order remain local because they are device/timing-specific.

## Access and connection

Each desktop reads and writes only inside the chosen Drive for Desktop folder, using the signed-in user's existing Drive Desktop authorization. On Mac, set `CHATGPT_ALERT_SHARED_STATE_DIR` to the synced `state-v1` folder. Windows must use the same schema and merge rules, but its implementation is pending until the Windows computer is available. Never treat a local DriveFS write as proof that the remote cloud has finished syncing.

If Drive Desktop is unavailable, the client continues using local settings and reports shared state as unavailable; it must not repeatedly trigger sign-in dialogs. When a configured directory disappears or becomes unwritable, surface one actionable desktop alert and retry only after a bounded delay or an explicit user action. Reconnect and conflict behavior still require Windows parity and runtime validation.

## Mac helper status

`drive-state.py` is a small, standalone prototype for app preferences and opaque work-status IDs. It writes immutable events and reads merged latest values. It is not yet wired into the alert UI, and does not provide cloud-sync acknowledgement. Windows implementation, UI controls, authenticated DriveFS round-trip, and native desktop smoke tests remain pending.
