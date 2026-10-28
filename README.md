# codex-mac-gui-unlock

**EXPERIMENTAL / GUI UNLOCK UNVERIFIED. No successful physical-Mac unlock is established.**

An on-demand Swift app and Codex skill for investigating recovery of the owner's existing, same-user macOS console session after an ordinary screen lock. This is not an official OpenAI integration. Read [VERIFICATION.md](VERIFICATION.md) for actual observations and [SECURITY.md](SECURITY.md) before enrolling a credential.

The problem is a GUI task that stops with “The Mac is locked and automatic unlock could not unlock it.” A shell process continuing is not GUI recovery. The success criterion is an independently observed unlocked session **and the original pending Computer Use operation succeeding**.

No sleep prevention, Bluetooth proximity service, launch agent, automatic startup, network listener, telemetry, authorization plug-in, or system security modifications are included. FileVault preboot, cold boot, logout/login, other users, sleep/wake and hardware authentication bypass are unsupported. The deployment target is a build setting, not a compatibility claim. Only the environment recorded in VERIFICATION.md has been examined.

## Build and install

Requires macOS, Xcode or Command Line Tools with Swift 5.9 or newer, and Python 3. The app uses only Apple frameworks; the Python scripts use only the standard library.

From a fresh checkout:

```sh
python3 scripts/install.py
```

This builds and ad-hoc signs `Codex Mac GUI Unlock.app`, installs it in `~/Applications`, registers it with LaunchServices and creates a collision-checked symlink at `~/.agents/skills/mac-gui-unlock`. No credentials are enrolled by installation. The checkout must stay in place because the skill points to it. Existing unrelated apps, skills and manifests are refused. Identical repeated installation is supported. A changed executable requires revoke and uninstall before reinstalling.

```sh
./scripts/mac-gui-unlock status
./scripts/mac-gui-unlock preflight
python3 scripts/check-skill.py --codex /path/to/codex
```

`check-skill.py` uses the local app-server `skills/list` method, without starting a model turn. `$mac-gui-unlock` is the skill invocation. Discovery in an existing running conversation may require a new turn or an app restart; do not restart an active GUI task just to reload skills. Discovery evidence is distinct from an agent turn actually invoking the skill.

## Local human enrollment and permission

1. While the Mac is unlocked, run `./scripts/mac-gui-unlock permissions`. The owner approves the helper in System Settings → Privacy & Security → Accessibility and any event-control prompt. Permission is checked inside the LaunchServices-launched app, not inherited from a shell or Codex.
2. Run `./scripts/mac-gui-unlock setup`. The owner reads the opt-in warning, types the Mac login password into the **native masked field only**, and chooses Save locally and opt in. Cancel is safe. Never supply it in chat, command arguments, environment variables, clipboard, files or scripts.
3. Enrollment stores a dedicated, non-synchronizing login Keychain item with an ACL restricted to the installed app executable. It does not establish a successful unlock. Rebuilding changes an ad-hoc signature and can require new TCC approval and local enrollment.

**Automatic unlocking can expose your desktop to anyone physically present.** This app does not reproduce OpenAI's display shields. A signed app in a user-writable folder is not protection from malicious code already running as that user. See the threat model.

## One bounded task grant

Use a non-sensitive UUID to identify the chosen local task. The owner must approve a native grant dialog while unlocked:

```sh
./scripts/mac-gui-unlock grant --task TASK-UUID
```

Replace `TASK-UUID` with an actual UUID (for example, generate one with `uuidgen`). The grant lasts at most 120 seconds, binds the current security session and UID, and permits one attempt. A failed preflight inside `unlock-once` consumes it. A new grant replaces any old grant and always requires fresh local approval. There is no automatic renewal or persistent unlock service.

During an ordinary locked-session GUI failure:

```sh
python3 .agents/skills/mac-gui-unlock/scripts/recover.py --task TASK-UUID
```

The orchestrator checks status/preflight, calls `unlock-once` at most once, and independently checks status. It emits `gui_verified: false` even after OS-level recovery. The calling Codex skill must preserve the pending GUI call and retry **only that call once** through Computer Use, then inspect the resulting GUI. It cannot call an in-memory Computer Use API from a separate process. Any error, focus loss, unknown outcome, timeout or relock requires a human unlock. Do not retry or clear the password field.

The strict empty-field guard may block on macOS versions that hide secure-field character counts. This is intentional; there is no permissive fallback. Public AX and CGEvent APIs do not guarantee lock-screen authentication, and sending an event is not success.

## Results and exit codes

All launched commands produce redacted JSON receipts in `~/Library/Application Support/CodexMacGUIUnlock` (directory 0700, files 0600). These contain fixed result codes, booleans and a local numeric session ID; no usernames, paths, window text, password values or task text. They stay local and are not included in Git. The launcher prints only that receipt.

| Code | Meaning |
| --- | --- |
| 0 | Observed result or already-unlocked no-op; inspect `recovered` |
| 2 | Refused, missing prerequisite, cancelled or revoked |
| 3 | Input may have occurred, completion unknown or timeout; do not retry |
| 64 | Invalid invocation |
| 74 / 75 / 78 | Native receipt I/O / concurrency / app identity failure; launcher may report an unknown timeout |

`status` and `preflight` never retrieve the credential or emit keyboard input. An unlocked result does not mean permissions, enrollment, or lock-screen target access are ready.

## Revoke, rollback and uninstall

```sh
./scripts/mac-gui-unlock revoke
python3 scripts/uninstall.py
```

Revoke deletes only the dedicated Keychain item and grant. Uninstall first invokes revoke through the installed app, then removes only its matching app, manifest and skill link. It preserves unrelated files and retains redacted local receipts. Concurrent operations hold an exclusive lock; revoke may need to be run after an in-progress command ends. No grant can survive its 120-second bound.

If the app was manually removed before revocation, delete the item labeled **Codex Mac GUI Unlock (dedicated owner item)** in Keychain Access and delete `grant.json` in the private support directory. Do not change OpenAI's plug-in or authorization entries. TCC may retain a stale helper row; the owner may remove that row in System Settings. No security settings were automatically weakened or restored by this project.

## Development and review

```sh
./scripts/build.sh
swift test
python3 -m unittest discover -s Tests -v
shellcheck scripts/build.sh scripts/mac-gui-unlock
./scripts/scan.sh
```

The build uses a local ad-hoc signature, not a Developer ID certificate or notarization. Legacy Keychain ACL APIs produce deprecation warnings; they are intentionally retained for a dedicated local trusted-executable ACL. These warnings and all untested behavior are documented, not treated as proof of compatibility.

See [ARCHITECTURE.md](ARCHITECTURE.md), [SECURITY.md](SECURITY.md), [CONTRIBUTING.md](CONTRIBUTING.md), [ATTRIBUTIONS.md](ATTRIBUTIONS.md) and [LIVE-TESTS.md](LIVE-TESTS.md). GitHub Actions builds and tests without passwords or a live GUI; green CI cannot verify lock-screen unlock.

MIT for original source. No upstream password-handling code is executed or vendored.
