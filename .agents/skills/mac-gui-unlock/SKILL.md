---
name: mac-gui-unlock
description: Diagnose and attempt one locally authorized recovery only after macOS GUI Computer Use reports a locked-session unlock failure. Use explicitly as $mac-gui-unlock or for that specific failure; exclude ordinary GUI tasks, sleep, boot, logout, and other users.
---

This experimental helper has no established GUI unlock compatibility. Read the project's VERIFICATION.md before making a compatibility claim.

Use the installed script `scripts/mac-gui-unlock.py` relative to this skill. It launches the signed native app through LaunchServices. Never execute the app binary from a terminal as a substitute for its app identity.

1. Preserve the exact failed GUI operation and its app target. Confirm the shell/tool runner still works with a non-sensitive command. If all tools are blocked, stop for a normal human unlock; the skill cannot run itself. No background daemon is installed.
2. Call `status`, then `preflight`. Read the JSON, including `recovered`; exit zero alone is not unlock evidence. An already unlocked result is a no-op. Retry the original GUI operation once only if the same active desktop is independently visible.
3. If enrollment or permissions are missing, ask the owner to use local `permissions` and `setup` commands while unlocked. They must approve OS permissions and type a password only in the native masked prompt. Never accept secrets through chat, arguments, environment, clipboard, or a file.
4. Recovery requires an unconsumed local grant for this exact task UUID. The owner runs `grant --task UUID` and approves the native dialog while unlocked. It expires after 120 seconds and permits one attempt. Never create or renew grants silently. If no such grant exists, stop for local human action.
5. Call `scripts/recover.py --task UUID` once to perform status/preflight, a single `unlock-once`, and independent status. On any blocked, unknown, timeout, partial-input, failed or consumed-grant response, stop and request normal human unlock. Do not clear fields, change focus, synthesize extra input, fetch credentials elsewhere, or retry the attempt. The grant remains consumed.
6. If the receipt reports `recovered: true`, call `status` independently and verify the same session is unlocked, then retry only the failed GUI operation once through Computer Use. Verify the app state. Only that observable GUI continuation establishes end-to-end success. If it relocks, stop. Never replay the entire task.

Automatic unlocking can expose the desktop to anyone physically present. The helper cannot authenticate a Codex task cryptographically; its local UUID grant limits accidental scope but same-user processes are in the threat boundary. Use `revoke` to cancel grants and delete the dedicated Keychain item; use the project's `scripts/uninstall.py` to remove only its installation.

Do not access OpenAI's internal authorization plug-in interfaces, change authorization rules, disable protections, or replace recovery with sleep prevention. Report Chrome Remote Desktop interactions as observed, not inferred.
