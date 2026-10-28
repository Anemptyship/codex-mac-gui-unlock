# Verification record

**EXPERIMENTAL / GUI UNLOCK UNVERIFIED. Physical Mac GUI recovery: FAIL (missing helper permission; no credential input).**

Date: 2026-10-28. Helper version: 0.1.0. No successful credential submission, independent session unlock by this helper, or resumed GUI operation has been demonstrated. Do not infer support from a successful build.

## Examined environment (anonymized)

| Item | Observed value |
| --- | --- |
| macOS | 26.6.2 |
| Build | 25G83 |
| Architecture | arm64 |
| Swift | Apple Swift 6.4 |
| Developer tools | Xcode developer directory available |
| ChatGPT/Codex app version | 26.1013.31256 |
| Console | Caller UID matches active console owner and caller security session |
| Official Computer Use helper | Running; strict deep code-signature verification passed |
| Official Locked Use plug-in | Bundle exists; left untouched |
| Locked Use setting | Owner reports enabled; switch not independently inspected |
| Chrome Remote Desktop | Host processes present; phone connection/disconnection not verified |

No private paths, user names, machine identifiers, personal logs, screenshots or credentials are included. Other macOS versions are untested for GUI unlock. The CI runner's OS is a build environment only.

## Actual local results

| Check | Result and evidence |
| --- | --- |
| Native release build | PASS, `scripts/build.sh`; app ad-hoc signed and `codesign --verify --deep --strict` passed |
| Swift tests | PASS, 11 tests, zero failures |
| Python installer/recovery tests | PASS, 9 tests, zero failures |
| ShellCheck | PASS for build/launcher/scan shell scripts |
| Skill validator | PASS with the local skill-creator `quick_validate.py` |
| Secret scan | PASS with Gitleaks 8.30.1 (redacted source scan); private-path/artifact source checks passed |
| User installation | PASS; installed signed app and `~/.agents/skills/mac-gui-unlock/SKILL.md` |
| Installer repeatability | PASS on the actual user installation and isolated roots |
| Collision safety | PASS in disposable roots; foreign skill and modified app preserved |
| Revoke/uninstall/reinstall | PASS on the actual user installation both before enrollment and after the live trial. The enrolled dedicated credential and grant were revoked; app/skill were removed and reinstalled without enrolling a credential. Repeated revoke succeeded |
| Skill discovery | PASS; installed Codex app-server `skills/list` returned `mac-gui-unlock` with no protocol error |
| Actual agent turn with `$mac-gui-unlock` | NOT TESTED; discovery is not evidence of model invocation or GUI recovery |
| Native local enrollment | PASS; app returned `enrolled` after its masked local opt-in dialog; no password inspected or printed. Credential was subsequently revoked after the failed live trial |
| Final helper TCC permissions | NOT APPROVED at latest observation: Accessibility=false, eventPosting=false inside the installed app |
| Missing/revoked grant | PASS live: `unlock-once` returned exit 2, `grant_absent_expired_revoked_or_consumed`, submitted=false, recovered=false |
| Already unlocked | PASS live status/preflight no-op, submitted=false, recovered=false |
| Full ordinary-lock recovery A | FAIL: Finder GUI baseline observed, normal Control-Command-Q lock applied, same session reported locked, one locally granted attempt refused with `permissions_missing`; no credential submission or GUI continuation |
| Chrome Remote Desktop recovery B | NOT TESTED; requires owner's iPhone connection/disconnection and a new bounded local grant |
| GitHub authentication/publication | PASS via existing browser sign-in and connected GitHub API; public repository `Anemptyship/codex-mac-gui-unlock` loads, 32 source files and MIT license present, local and remote source tree/commit matched. `gh` remains unauthenticated; no credential was exported |
| GitHub Actions | PASS: [run 40685671087](https://github.com/Anemptyship/codex-mac-gui-unlock/actions/runs/40685671087), commit `4f8477cd53f18176ab36d4573743325c99384751`; native build, Swift/Python tests, ShellCheck and source/history scans all succeeded |

## Minimal live lock/runner experiment

Computer Use inventory initially responded. A subsequent native TextEdit request, `cua.getApp("com.apple.TextEdit")`, returned exactly:

> The Mac is locked and automatic unlock could not unlock it. Ask the user to unlock the Mac manually before continuing.

Immediately afterward, a non-sensitive shell command ran successfully. A separate Swift OS probe reported: caller console/security-session match=true, `IOConsoleLocked=true`, display asleep=false. This establishes that the runner remained callable **after that actual GUI lock failure** on this Mac. It does not establish why the lock occurred or whether every future failure leaves tools available. No credential was read during the probe.

The desktop was later observed unlocked by the installed helper, with `recovered=false`. No helper unlock had run, so that transition is not attributed to the project. A later TextEdit request returned `Computer Use server error -10005: timeoutReached` while a subsequent OS status reported unlocked. That timeout is distinct from proof of a locked OS session and is not presented as a successful GUI baseline.

A local application rebuild changed its ad-hoc code identity. The earlier app briefly reported AX/event permissions=true; the final enrolled build reported both false. This demonstrates why permission checks must be performed inside the exact app build and why consent cannot be assumed to transfer from Codex, a CLI caller, or a previous build.

## Authorized ordinary-lock trial

After a later Finder Computer Use call successfully returned its Desktop/menu accessibility state, the owner approved a native one-attempt grant. The launcher had timed out waiting for that local interaction; the subsequently stored grant was independently checked and still valid with 55 seconds remaining. No timeout was treated as authorization: only the native dialog's stored local grant enabled the test.

Control-Command-Q was sent through the existing Finder Computer Use binding. Immediately afterward, the installed app reported the same console session locked. Status and preflight both reported `permissions_missing`; Accessibility and eventPosting were false. One `unlock-once` request durably consumed the locally approved grant and returned exit 2, `submitted=false`, `recovered=false`. A deliberate negative-case request using that consumed grant returned `grant_absent_expired_revoked_or_consumed`, again with no input. There was no password submission or automatic retry. Private JSON receipts remain in the helper's owner-only support directory.

This is a live **FAIL to recover the GUI**, with missing helper TCC permission as the observed blocker. It does not demonstrate that macOS would accept or deny native password input after that permission is granted. Normal human unlock and permission approval were requested. The OS later reported unlocked again without a helper submission; that transition is not attributed to this project. Final helper permissions remained false. Chrome Remote Desktop phone testing has not occurred.

## Negative cases and coverage limits

Injected tests cover absent session, wrong user/session, unknown lock state, already unlocked, missing AX/posting access, sleeping display, unverified secure focus, unknown/nonempty field, missing/revoked credential, focus change after credential access, partial input, unknown unlock, independently changed session, used/expired/revoked grant and clock rollback. They assert no credential/input calls for refused states and no retry after input failure. Recovery tests require independent status and leave GUI verification explicitly false.

These are synthetic safety tests, not real logout, preboot, sleep or wrong-user trials on the owner's active Mac. No FileVault, logout or other-account authentication was attempted. A real grant was consumed after a permission refusal, and reuse was denied. Live revoke after enrollment returned success and removed the dedicated credential/grant; uninstall/reinstall and repeat revoke also succeeded. Focus loss during actual password entry and actual lockout handling have not been tested. Those cases must not be labeled live PASS.

## Final local state

The helper and skill remain installed, but the dedicated password item and all grants have been revoked. The host is not configured for automatic unlocking, and no background unlock service was installed. The OS was last observed unlocked. To conduct another actual input trial, the owner must approve the exact installed app's Accessibility/event permissions, enroll locally again and approve a fresh one-attempt grant. Local redacted receipts are retained outside the repository.

## Remaining verification procedure

Complete local helper permission approval. GitHub CLI authentication is optional when publication uses the existing connected GitHub API. Establish a harmless TextEdit GUI baseline. Approve one native task-specific grant, run ordinary Control-Command-Q lock, attempt once, and verify both independent same-session unlock and continuation of the exact pending GUI operation. Repeat after an owner-confirmed Chrome Remote Desktop iPhone connect/disconnect. Follow LIVE-TESTS.md and stop after any failure; preserve private receipts locally.

Publish only with this experimental label unless those specific live tests actually pass. GitHub CI build/test results must be recorded separately from physical GUI evidence. No stable release is justified by the present record.
