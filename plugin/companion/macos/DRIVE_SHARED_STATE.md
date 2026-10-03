# Shared Drive state (Mac-first proposal)

## Authority and location

GitHub `main` remains authoritative for app source. The created Drive location is `My Drive/ChatGPT Attention Alert Shared State/state-v1`. Google Drive owns only shared, non-sensitive state there. Both PCs should sign in to the same Drive account and point to this folder. The folder is not shared with additional accounts. Do not use Drive API tokens or put credentials in this repository.

## Data and merge rules

Store one immutable JSON event per update under `events/<UUID>.json`. Events contain schema version, event UUID, logical key, allowlisted value, per-key logical version, and UTC timestamp. Clients increment the highest version they have observed for that key; concurrent writes at the same version are resolved by event UUID lexicographically. This avoids relying on wall-clock order and retains both concurrent events for deterministic review. Legacy events without a logical version are ordered by timestamp until the first versioned update for that key. Invalid or unknown fields are ignored; clients never delete events. A later compaction must be opt-in and retain a recoverable backup.

The allowlist is intentionally limited to non-sensitive app preferences (`sound`, `recommendations`) and coarse user-authored work status with opaque UUIDs and enum values (`todo`, `in_progress`, `done`). Do not sync alert title/body/chat URL, login links, account names, student data, custom sound paths, recommendation history, or machine-local paths. Pause timers and stack order remain local because they are device/timing-specific.

## Access and connection

Each desktop reads and writes only inside the chosen Drive for Desktop folder, using the signed-in user's existing Drive Desktop authorization. On Mac, run `chatgpt-attention-alert --shared-state-dir "/path/to/My Drive/ChatGPT Attention Alert Shared State/state-v1"` using the local path shown by Drive for Desktop. Windows must use the same schema and merge rules, but its implementation is pending until the Windows computer is available. Never treat a local DriveFS write as proof that the remote cloud has finished syncing.

If the configured folder cannot be read or written, the client continues using local settings and shows one actionable desktop notice per filesystem-access failure episode; it must not repeatedly trigger sign-in dialogs. Google Drive for Desktop owns account sign-in and approval prompts. The companion cannot reliably detect an expired Drive session when DriveFS still accepts local writes, so DriveFS sync status remains the authority for upload/authentication state. Reconnect and conflict behavior still require Windows parity and runtime validation.

## Mac helper status

`drive-state.py` is installed with the Mac companion. The companion reads shared preferences for each alert, writes preference toggles and work-status changes as immutable events, and uses local preferences when the folder cannot be reached. It records a local one-shot marker and posts one notification per outage episode; the health check runs only when the companion is used, not in a background monitor. Cloud-sync acknowledgement is not available. Windows implementation, authenticated DriveFS round-trip, and native desktop smoke tests remain pending.
