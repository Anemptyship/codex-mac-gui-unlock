import AppKit
import ApplicationServices
import Security
import SystemConfiguration
import IOKit
import Darwin
import UnlockCore

let appID = "org.codexcommunity.MacGUIUnlock"
let installedApp = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Codex Mac GUI Unlock.app")
let keyService = appID + ".owner-password"
func boolValue(_ value: Any?) -> Bool? {
    guard let value, CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID() else { return nil }
    return (value as! NSNumber).boolValue
}
func ax(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}
func processUID(_ pid: pid_t) -> uid_t? {
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
    var info = kinfo_proc(); var length = MemoryLayout<kinfo_proc>.size
    guard sysctl(&mib, u_int(mib.count), &info, &length, nil, 0) == 0,
          length == MemoryLayout<kinfo_proc>.size else { return nil }
    return info.kp_eproc.e_ucred.cr_uid
}
struct PasswordTarget { let pid: pid_t; let field: AXUIElement }
func target() -> PasswordTarget? {
    let apps = NSWorkspace.shared.runningApplications.filter {
        $0.bundleIdentifier == "com.apple.loginwindow" && !$0.isTerminated &&
        $0.executableURL?.path == "/System/Library/CoreServices/loginwindow.app/Contents/MacOS/loginwindow" &&
        processUID($0.processIdentifier) == getuid()
    }
    guard apps.count == 1 else { return nil }
    let pid = apps[0].processIdentifier
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.25)
    guard let raw = ax(app, kAXFocusedUIElementAttribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
    let field = raw as! AXUIElement
    AXUIElementSetMessagingTimeout(field, 0.25)
    var owner: pid_t = 0
    guard AXUIElementGetPid(field, &owner) == .success, owner == pid,
          ax(field, kAXRoleAttribute) as? String == kAXTextFieldRole,
          ax(field, kAXSubroleAttribute) as? String == kAXSecureTextFieldSubrole,
          boolValue(ax(field, kAXFocusedAttribute)) == true,
          boolValue(ax(field, kAXEnabledAttribute)) == true else { return nil }
    let system = AXUIElementCreateSystemWide()
    AXUIElementSetMessagingTimeout(system, 0.25)
    guard let focusedRaw = ax(system, kAXFocusedApplicationAttribute),
          CFGetTypeID(focusedRaw) == AXUIElementGetTypeID() else { return nil }
    var focusedPID: pid_t = 0
    guard AXUIElementGetPid(focusedRaw as! AXUIElement, &focusedPID) == .success,
          focusedPID == pid else { return nil }
    return PasswordTarget(pid: pid, field: field)
}
func empty(_ field: AXUIElement) -> Bool {
    guard let n = ax(field, kAXNumberOfCharactersAttribute) as? NSNumber,
          CFGetTypeID(n) != CFBooleanGetTypeID() else { return false }
    return n.doubleValue == 0
}
func observe(inspectTarget: Bool = true) -> Observation {
    var o = Observation()
    o.accessibility = AXIsProcessTrusted(); o.eventPosting = CGPreflightPostEventAccess()
    o.displayAwake = CGDisplayIsAsleep(CGMainDisplayID()) == 0
    guard getuid() > 0, getuid() == geteuid(),
          let cg = CGSessionCopyCurrentDictionary() as? [String: Any],
          let uid = cg[kCGSessionUserIDKey as String] as? NSNumber, uid.uint32Value == getuid(),
          boolValue(cg[kCGSessionOnConsoleKey as String]) == true,
          boolValue(cg[kCGSessionLoginDoneKey as String]) == true,
          let sid = cg["kSCSecuritySessionID"] as? NSNumber, sid.uint64Value > 0,
          sid.uint64Value <= UInt32.max else { o.reason = "console_unverified"; return o }
    var securitySession: SecuritySessionId = 0; var flags: SessionAttributeBits = []
    var consoleUID: uid_t = 0; var consoleGID: gid_t = 0; var st = stat()
    guard SessionGetInfo(callerSecuritySession, &securitySession, &flags) == errSecSuccess,
          sid.uint32Value == securitySession,
          let user = SCDynamicStoreCopyConsoleUser(nil, &consoleUID, &consoleGID) as String?,
          user != "loginwindow", user != "_mbsetupuser", consoleUID == getuid(),
          lstat("/dev/console", &st) == 0, st.st_uid == getuid() else { o.reason = "console_unverified"; return o }
    o.ownSession = true; o.session = securitySession
    let root = IORegistryGetRootEntry(kIOMainPortDefault)
    if root != 0 {
        defer { IOObjectRelease(root) }
        if let raw = IORegistryEntryCreateCFProperty(root, "IOConsoleLocked" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue(), let locked = boolValue(raw) {
            o.state = locked ? .locked : .unlocked
        }
    }
    if inspectTarget && o.state == .locked && o.accessibility && o.eventPosting, let t = target() {
        o.targetVerified = true; o.emptyField = empty(t.field)
    }
    o.reason = refusal(o) ?? "ready"
    return o
}
func sameTarget(_ t: PasswordTarget, _ initial: Observation) -> Bool {
    let now = observe(inspectTarget: false)
    guard sameSession(initial, now), now.state == .locked, now.displayAwake,
          now.accessibility, now.eventPosting, let current = target() else { return false }
    return current.pid == t.pid && CFEqual(current.field, t.field)
}
func credentialQuery() -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keyService,
     kSecAttrAccount as String: "owner-uid-\(getuid())", kSecAttrSynchronizable as String: false,
     kSecUseDataProtectionKeychain as String: false]
}
func readCredential() -> Data? {
    guard SecKeychainSetUserInteractionAllowed(false) == errSecSuccess else { return nil }
    var query = credentialQuery(); query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
    var data: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &data) == errSecSuccess else { return nil }
    return data as? Data
}
func deleteCredential() -> Bool {
    SecKeychainSetUserInteractionAllowed(false)
    let result = SecItemDelete(credentialQuery() as CFDictionary)
    return result == errSecSuccess || result == errSecItemNotFound
}
func validPassword(_ value: String) -> Bool {
    !value.isEmpty && value.utf16.count <= 256 && !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
}
func localAlert(_ title: String, _ message: String, secure: Bool = false) -> (Bool, String) {
    let app = NSApplication.shared; app.setActivationPolicy(.accessory)
    let alert = NSAlert(); alert.messageText = title; alert.informativeText = message
    alert.addButton(withTitle: secure ? "Save locally and opt in" : "Allow one attempt")
    alert.addButton(withTitle: "Cancel")
    let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
    if secure { alert.accessoryView = field; alert.window.initialFirstResponder = field }
    app.activate(ignoringOtherApps: true)
    let approved = alert.runModal() == .alertFirstButtonReturn
    let value = secure && approved ? field.stringValue : ""
    field.stringValue = ""
    return (approved, value)
}
func enroll() -> String {
    let before = observe(inspectTarget: false)
    guard before.ownSession, before.state == .unlocked else { return "setup_requires_unlocked_console" }
    let (yes, value) = localAlert("Codex Mac GUI Unlock — local enrollment", "EXPERIMENTAL. Automatic unlocking can expose your desktop to anyone physically present. Enter your Mac login password here only. It is stored in a dedicated, non-synchronizing Keychain item restricted to this signed app. Each attempt still requires a separate 120-second local grant. Never enter it in chat. Revoke deletes the item and all grants.", secure: true)
    guard yes else { return "cancelled" }
    guard validPassword(value) else { return "unsupported_password_format" }
    let after = observe(inspectTarget: false)
    guard sameSession(before, after), after.state == .unlocked else { return "session_changed" }
    var trusted: SecTrustedApplication?; var access: SecAccess?
    guard let path = Bundle.main.executableURL?.path,
          SecTrustedApplicationCreateFromPath(path, &trusted) == errSecSuccess, let trusted,
          SecAccessCreate("Codex Mac GUI Unlock owner password" as CFString, [trusted] as CFArray, &access) == errSecSuccess, let access else { return "keychain_acl_failed" }
    var data = Data(value.utf8); defer { data.resetBytes(in: 0..<data.count) }
    var query = credentialQuery()
    let updates: [String:Any] = [kSecValueData as String:data, kSecAttrAccess as String:access]
    let status = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
    if status == errSecSuccess { return "enrolled" }
    guard status == errSecItemNotFound else { return "keychain_write_denied" }
    updates.forEach { query[$0.key] = $0.value }
    query[kSecAttrLabel as String] = "Codex Mac GUI Unlock (dedicated owner item)"
    return SecItemAdd(query as CFDictionary, nil) == errSecSuccess ? "enrolled" : "keychain_write_denied"
}
// PID-directed events are experimental. Public APIs do not provide an atomic
// focus-check-and-deliver operation; focus races remain a documented limitation.
func submit(_ data: Data, to t: PasswordTarget, initial: Observation) -> (submitted: Bool, complete: Bool) {
    guard let text = String(data: data, encoding: .utf8), validPassword(text), empty(t.field),
          let source = CGEventSource(stateID: .privateState) else { return (false, false) }
    var units = Array(text.utf16)
    defer { _ = units.withUnsafeMutableBytes { $0.initializeMemory(as: UInt8.self, repeating: 0) } }
    var pairs: [(CGEvent,CGEvent)] = []
    for offset in stride(from: 0, to: units.count, by: 16) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return (false,false) }
        down.flags = []; up.flags = []
        units.withUnsafeBufferPointer { down.keyboardSetUnicodeString(stringLength: min(16, units.count-offset), unicodeString: $0.baseAddress!+offset) }
        pairs.append((down,up))
    }
    guard let enter = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: true),
          let release = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: false) else { return (false,false) }
    enter.flags = []; release.flags = []; pairs.append((enter,release))
    var emitted = false
    for (down,up) in pairs {
        guard sameTarget(t, initial) else { return (emitted,false) }
        down.postToPid(t.pid); up.postToPid(t.pid); emitted = true
    }
    return (emitted,true)
}
func confirmed(_ initial: Observation) -> Bool {
    let deadline = ProcessInfo.processInfo.systemUptime + 8
    var stable = 0
    while ProcessInfo.processInfo.systemUptime < deadline {
        let now = observe(inspectTarget: false)
        guard sameSession(initial, now) else { return false }
        stable = now.state == .unlocked && now.displayAwake ? stable + 1 : 0
        if stable == 3 { return true }
        Thread.sleep(forTimeInterval: 0.2)
    }
    return false
}
