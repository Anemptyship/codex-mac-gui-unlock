# Physical Mac verification protocol

Only the owner supplies credentials and approves permissions, locally. Stop after any denied/unknown attempt. Do not keep submitting the same password. Preserve raw receipts in the private support directory; publish only anonymized facts, not session IDs, paths, screenshots, task UUIDs or usernames.

## A: ordinary screen lock and same GUI operation

1. With an unlocked desktop, create a disposable TextEdit document containing `GUI recovery check: before`. Observe that exact text via Computer Use. Leave unrelated documents untouched.
2. After local enrollment and permission approval, choose a new task UUID and approve one local grant. The 120-second window must cover the following steps.
3. Lock normally with Control-Command-Q while the task is active. Do not sleep, log out, or reboot. Call the preserved TextEdit GUI read and record whether official Locked Use succeeds or returns its exact lock error.
4. Prove a harmless shell call still runs. Call status and preflight, then the recovery wrapper at most once for the granted UUID. Do not weaken guards if loginwindow or the secure empty field cannot be verified.
5. If OS recovery is confirmed, independently call status, retry only the pending TextEdit read once through Computer Use, append `GUI recovery check: after` and read it back. A PASS requires all of those observations, not just key events or exit zero.
6. Revoke. If a guard fails or the task relocks, record FAIL with the exact blocker and ask the owner to unlock normally.

## B: Chrome Remote Desktop reproduction

The owner connects from their iPhone using Chrome Remote Desktop, then disconnects. Record only that connection lifecycle was observed/confirmed; never collect its PIN, session token or remote screen contents. Repeat A with a fresh locally approved grant. Observe whether official Locked Use relocks after remote input. A running host process alone is not proof of a phone connection or causation.

## C: negative cases

Use injected unit tests for unsafe session states, unknown lock state, missing permissions, missing/revoked credential, changed focus, partial input, failed verification, clock/session changes and used/revoked/expired grants. Do not log out or attempt FileVault authentication on the owner's active machine just to produce a negative test.

Live safe cases: already unlocked status/preflight; new app identity without TCC consent; unlock-once with no grant; revoke; repeated invocation after revoke; read-only locked preflight with no credential access. After a genuine failed attempt, a second request must be refused because the durable grant is consumed. Record simulated and live cases separately.

## D: installation and discovery

Check `~/.agents/skills/mac-gui-unlock/SKILL.md`, invoke local Codex `skills/list` with `scripts/check-skill.py`, and separately record whether an actual `$mac-gui-unlock` turn ran. Install twice, test collision preservation in a disposable root, revoke, uninstall, and reinstall. Ensure unrelated host files remain. Run a source scan before pushing verification notes.
