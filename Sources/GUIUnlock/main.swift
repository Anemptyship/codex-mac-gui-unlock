import AppKit
import ApplicationServices
import Security
import UnlockCore
import Darwin

// Only fixed verbs, UUID request/task identifiers: never accept passwords or paths.
let arguments = Array(CommandLine.arguments.dropFirst())
func argument(_ key: String) -> String? {
    guard let i = arguments.firstIndex(of: key), i+1 < arguments.count else { return nil }
    return arguments[i+1]
}
let allowed = ["status", "preflight", "permissions", "setup", "grant", "unlock-once", "revoke", "uninstall"]
guard arguments.count == 4 || arguments.count == 6,
      Set(stride(from: 0, to: arguments.count, by: 2).map { arguments[$0] }).count == arguments.count/2,
      stride(from: 0, to: arguments.count, by: 2).allSatisfy({ ["--command","--request","--task"].contains(arguments[$0]) }),
      let command = argument("--command"), allowed.contains(command),
      let rawID = argument("--request"), let requestID = UUID(uuidString: rawID) else { exit(64) }
let taskID = argument("--task").flatMap(UUID.init(uuidString:))
if ["grant","unlock-once"].contains(command) && taskID == nil { exit(64) }
// Installed LaunchServices app identity; direct CLI execution is unsupported.
var staticCode: SecStaticCode?
guard Bundle.main.bundleIdentifier == appID,
      Bundle.main.bundleURL.resolvingSymlinksInPath() == installedApp.resolvingSymlinksInPath(),
      SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &staticCode) == errSecSuccess,
      let staticCode, SecStaticCodeCheckValidity(staticCode, SecCSFlags(rawValue: kSecCSStrictValidate), nil) == errSecSuccess else { exit(78) }
guard let store = try? Store() else { exit(75) }
let initial = observe()
func finish(_ result: String, _ code: Int32, submitted: Bool = false, recovered: Bool = false) -> Never {
    let receipt = Receipt(command: command, result: result, exitCode: code, submitted: submitted, recovered: recovered, observation: observe())
    // Request UUID is only a local correlation value; receipts contain no names, paths, passwords, AX values or task text.
    let recorded = store.write(receipt, name: requestID.uuidString + ".json")
    exit(recorded ? code : 74)
}
switch command {
case "status": finish(initial.reason, initial.ownSession && initial.state != .unknown ? 0 : 2)
case "preflight": finish(initial.reason, initial.reason == "ready" || initial.reason == "already_unlocked" ? 0 : 2)
case "permissions":
    guard initial.ownSession, initial.state == .unlocked else { finish("requires_unlocked_console", 2) }
    NSApplication.shared.setActivationPolicy(.accessory)
    _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    _ = CGRequestPostEventAccess()
    finish("permission_request_shown_check_system_settings", 2)
case "setup":
    let result = enroll(); finish(result, result == "enrolled" ? 0 : 2)
case "grant":
    guard initial.ownSession, initial.state == .unlocked else { finish("grant_requires_unlocked_console", 2) }
    let (approved, _) = localAlert("Authorize one experimental unlock attempt?", "For the selected local task only, valid for 120 seconds and at most one attempt. The attempt is consumed even if preflight fails. Your desktop may become accessible to anyone physically present. No daemon or listener is installed. Revoke cancels the grant and deletes the dedicated credential.")
    guard approved else { finish("cancelled", 2) }
    let now = observe(inspectTarget: false)
    guard sameSession(initial, now), now.state == .unlocked else { finish("session_changed", 2) }
    let grant = Grant(task: taskID!, session: now.session, uid: getuid(), now: Date(), uptime: ProcessInfo.processInfo.systemUptime)
    guard store.write(grant, name: "grant.json") else { finish("grant_write_failed", 2) }
    finish("one_attempt_granted_120_seconds", 0)
case "revoke", "uninstall":
    let removed = store.remove("grant.json")
    let deleted = deleteCredential()
    finish(removed && deleted ? "revoked" : "revoke_incomplete", removed && deleted ? 0 : 2)
case "unlock-once":
    guard var grant = store.read("grant.json", as: Grant.self), grant.permits(task: taskID!, observation: initial, uid: getuid(), now: Date(), uptime: ProcessInfo.processInfo.systemUptime) else { finish("grant_absent_expired_revoked_or_consumed", 2) }
    grant.used = true
    guard store.write(grant, name: "grant.json") else { finish("grant_consume_failed", 2) }
    if let reason = refusal(initial) { finish(reason, reason == "already_unlocked" ? 0 : 2) }
    guard let t = target(), sameTarget(t, initial), empty(t.field) else { finish("focus_changed", 2) }
    // No Keychain read before every session, lock, display, permission, focus and emptiness guard passes.
    let result = attemptOnce(observation: initial,
        validateTarget: { sameTarget(t, initial) && empty(t.field) },
        readSecret: readCredential,
        post: { data in
            let outcome = submit(data, to: t, initial: initial)
            return InputOutcome(emitted: outcome.submitted, complete: outcome.complete)
        }, verify: { confirmed(initial) })
    finish(result.reason, result.code, submitted: result.submitted, recovered: result.recovered)
default: finish("invalid_command", 64)
}
