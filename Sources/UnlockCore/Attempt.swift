import Foundation

public struct InputOutcome {
    public let emitted: Bool
    public let complete: Bool
    public init(emitted: Bool, complete: Bool) { self.emitted = emitted; self.complete = complete }
}
public struct AttemptResult {
    public let reason: String
    public let code: Int32
    public let submitted: Bool
    public let recovered: Bool
    public init(_ reason: String, _ code: Int32, _ submitted: Bool = false, _ recovered: Bool = false) {
        self.reason = reason; self.code = code; self.submitted = submitted; self.recovered = recovered
    }
}
/// Called only after a durable single-use grant has been consumed under the process lock.
/// Hooks allow tests to prove that denied conditions never reach credential access or input.
public func attemptOnce(observation: Observation, validateTarget: () -> Bool, readSecret: () -> Data?,
                        post: (Data) -> InputOutcome, verify: () -> Bool) -> AttemptResult {
    if let reason = refusal(observation) { return AttemptResult(reason, reason == "already_unlocked" ? 0 : 2) }
    guard validateTarget() else { return AttemptResult("focus_changed", 2) }
    guard var data = readSecret() else { return AttemptResult("credential_absent_or_access_denied", 2) }
    defer { data.resetBytes(in: 0..<data.count) }
    guard validateTarget() else { return AttemptResult("focus_changed", 2) }
    let input = post(data)
    guard input.complete else { return AttemptResult("input_aborted_do_not_retry", input.emitted ? 3 : 2, input.emitted) }
    guard verify() else { return AttemptResult("unlock_failed_or_unknown_do_not_retry", 3, true) }
    return AttemptResult("session_unlock_observed_verify_original_gui", 0, true, true)
}
