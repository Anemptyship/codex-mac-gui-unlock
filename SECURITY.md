# Security policy and review

**Experimental. GUI unlock is unverified. This is not a security boundary against another process running as the owner.**

## Threat model

Protect the owner's login credential from chat, arguments, environment, clipboard, plaintext files, logs, network traffic and accidental delivery into an unrelated UI. Limit a cooperative agent to one local task/session attempt during a 120-second grant. Refuse unverifiable conditions. Do not change macOS protections or invoke OpenAI plug-in internals.

The desktop may become accessible to anyone physically present after a successful unlock. Unlike official Locked Use, this app supplies no display cover or physical-input shield. Chrome Remote Desktop and OpenAI's lock guardian may change focus or relock the session. The helper cannot promise compatibility with their interaction.

Trusted components are macOS, loginwindow, WindowServer, the user's Keychain and consent, the inspected source/built app, the launcher and Codex runner. Same-user malware, administrator/root compromise, keyloggers, debugger access, malicious source edits and physical takeover of an unlocked desktop are outside the protection provided. A UUID is a scope identifier, not an authentication secret. Any process as the owner can request the installed app during a live grant. A process able to edit owner files can replace grant state or source. Local approval dialogs can also be spoofed by other owner processes. Do not enroll on a compromised machine.

## Reviewed controls

- Setup uses a native `NSSecureTextField` only while the caller and console security session match and the desktop is unlocked. The user explicitly accepts the physical-access warning. No secret is accepted by the CLI.
- Dedicated generic login Keychain item: non-synchronizing, trusted installed executable ACL, no credential export command. Access during recovery disables Keychain interaction; missing/locked/denied items stop the attempt. The login Keychain may itself remain unlocked during a screen lock; this app does not weaken its lock policy. Rebuilds invalidate ad-hoc identity/consent assumptions.
- Session proof combines CG session metadata, public `SessionGetInfo`, dynamic console UID and `/dev/console` ownership. Lock observation uses the `IOConsoleLocked` registry property; missing/nonboolean values are unknown. This property and session dictionary keys are OS implementation details, not promised stable unlock APIs. No fallback treats absence as unlocked.
- Input requires an awake display, app-specific AX/event permissions, a unique same-UID loginwindow with Apple's protected executable path/bundle ID, the system-wide focused application matching that PID, and its focused, enabled secure text field with an observable zero character count. No AX text/value is logged.
- Grant is task/session/UID bound with wall-clock and monotonic expiration and one durable consumed flag. Failed attempts remain consumed; a new grant always requires a local dialog. No timers trigger automatic input.
- Single-process lock uses owner-only directory/file checks, `O_NOFOLLOW`, `flock`, single-link regular-file checks and fsynced grant writes. Native grant and receipt files stay in a fixed private directory. Request and task arguments are UUIDs, not file paths. Receipts use unique filenames and fixed metadata.
- All events are allocated before input, directed to the verified loginwindow PID, with focus/session/permission revalidation before each pair. One Return submission maximum. No clearing, guessing, automatic resubmission, global HID fallback, plug-in IPC or system authorization changes.
- Success requires repeated same-session OS unlocked samples, followed by a fresh status from orchestration and verification of the original Computer Use operation. No-op, event posting and exit zero are not success evidence.
- Installer/uninstaller use identity, source and binary-hash ownership checks; foreign collisions are preserved. The uninstall app verb revokes, while the separate installer utility removes registration. Redacted receipts are retained locally.

## Remaining limitations from the source review

Public APIs cannot atomically validate focus and deliver an event. Focus can change between a guard and delivery, and a partial text event can remain in a field. The app stops without clearing or retrying. PID routing narrows exposure but does not eliminate that race. AX field visibility/emptiness may be unavailable, in which case recovery is blocked. No password replay was considered proven safe or functional merely because the code compiled.

Swift, AppKit and Security create internal copies of password data. Mutable buffers are cleared best-effort; complete memory erasure cannot be guaranteed. Credentials are not validated at enrollment to avoid an additional authentication attempt. A wrong enrolled password therefore remains a possible single failed macOS attempt, subject to OS authentication and lockout rules.

Local support data and the installed app are owner-writable. Atomic file operations reduce accidents and symlink problems within this threat model, but do not defend against an actively malicious owner process replacing parent directories, modifying source, or forging receipts. The launcher trusts the locally installed project app, not a pinned publisher identity. Ad-hoc signing is no notarization or supply-chain guarantee. LaunchServices errors, concurrent commands or identity rejection can result in receipt timeout; unknown means stop.

No independent professional audit has been performed. Automated tests exercise policy and ordering with injected dependencies; they do not emulate macOS loginwindow protection or prove event acceptance. Physical tests are listed separately in VERIFICATION.md. No stable release should be published until the selected environment passes a new local enrollment and GUI continuation test.

## Disclosure

Use this repository's GitHub **Security → Report a vulnerability** when private reporting is available. If it is unavailable, open a public issue requesting a private contact without including exploit details, passwords, tokens, screenshots or personal logs. Never upload a Keychain item. Supported security work currently applies only to the development branch; no stable supported release exists.
