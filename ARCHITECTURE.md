# Architecture

The declarative Codex skill preserves the exact pending GUI operation. Its Python recovery wrapper calls a LaunchServices launcher; the signed Swift app performs every permission check and credential operation under its own identity. A separate process cannot invoke the calling turn's in-memory `cua` binding, so the skill carries out the final GUI retry.

```text
Computer Use reports locked/unlock failure
  → prove a non-sensitive tool call still runs
  → status/preflight (no credential read)
  → one pre-existing local task grant
  → consume grant durably under exclusive lock
  → verify session, display, permissions, loginwindow, focus and empty field
  → Keychain read with interaction disabled
  → revalidate guards; one PID-directed input sequence
  → observe same session unlocked repeatedly
  → fresh status through LaunchServices
  → retry exact pending GUI call once; observe GUI result
```

If any step is blocked, unknown or unsuccessful, the agent asks for a normal human unlock and does not replay the task. The app never changes power settings, wakes a sleeping Mac, starts at login or listens for connections.

## Components

- `UnlockCore`: grant policy, result schema and injected attempt engine. Tests observe credential-read/input calls to ensure unsafe states never reach them.
- `GUIUnlock/Platform.swift`: console/session proof, AX target inspection, private Keychain item, native opt-in dialogs and experimental PID-directed CGEvent delivery.
- `GUIUnlock/Store.swift`: private directory, exclusive lock, bounded JSON reads and fsynced atomic writes.
- `GUIUnlock/main.swift`: strict command parsing, installed bundle/signature checks, durable grant consumption and redacted receipts.
- `.agents/skills/mac-gui-unlock/scripts`: LaunchServices and one-attempt recovery orchestration. No arbitrary operation/command execution argument exists.
- `scripts/install.py`, `scripts/uninstall.py`: app registration and skill link with collision/ownership safeguards. No system-wide installation.

## Identity and state

App bundle ID: `org.codexcommunity.MacGUIUnlock`; version: `0.1.0`.

Installation uses the fixed user Applications path. Execution from `.build` or a direct terminal binary is unsupported. LaunchServices establishes the app identity; the app checks the actual AX and posting permissions on each observation. The signed app path and bytes must stay stable after consent.

One `grant.json` contains a non-sensitive task UUID, UID, security session ID, wall-clock/uptime expiry and consumed flag. It contains no credential. There is no durable automatic-unlock opt-in independent of the grant: enrollment alone never triggers input. Receipts contain no task identifier or personal UI data and are stored outside the checkout. Both wall-clock and monotonic windows must still be valid. A changed security session or clock anomaly refuses the grant.

The session ID has only local scope. It is not exposed in public verification notes. `IOConsoleLocked` is read independently of event delivery. Final success still requires Computer Use to observe the intended app, because an unlocked OS session can remain inaccessible to the GUI runtime or be relocked immediately.

## Why no companion daemon

A live experiment showed the shell runner remained callable immediately after the exact Computer Use lock failure. An always-running recovery service is therefore unnecessary for the observed case. If future versions block all tools, this skill cannot recover itself. A future bounded on-demand companion would need a separately reviewed local grant protocol; this implementation does not silently add one.
