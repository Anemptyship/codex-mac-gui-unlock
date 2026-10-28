import Foundation

public enum LockState: String, Codable { case locked, unlocked, unknown }
public struct Observation: Codable, Equatable {
    public var ownSession = false
    public var session: UInt32 = 0
    public var state: LockState = .unknown
    public var accessibility = false
    public var eventPosting = false
    public var displayAwake = false
    public var targetVerified = false
    public var emptyField = false
    public var reason = "unobserved"
    public init() {}
}
public struct Grant: Codable {
    public var task: UUID
    public var session: UInt32
    public var uid: UInt32
    public var expires: Date
    public var deadlineUptime: TimeInterval
    public var used: Bool
    public init(task: UUID, session: UInt32, uid: UInt32, now: Date, uptime: TimeInterval) {
        self.task = task; self.session = session; self.uid = uid
        expires = now.addingTimeInterval(120); deadlineUptime = uptime + 120; used = false
    }
    public func permits(task: UUID, observation: Observation, uid: UInt32, now: Date, uptime: TimeInterval) -> Bool {
        !used && self.task == task && self.uid == uid && observation.ownSession &&
        observation.session == session && now < expires && uptime < deadlineUptime &&
        uptime >= deadlineUptime - 120 && now >= expires.addingTimeInterval(-120)
    }
}
public func refusal(_ o: Observation) -> String? {
    if !o.ownSession { return "wrong_or_unverifiable_session" }
    if o.state == .unknown { return "lock_state_unknown" }
    if o.state == .unlocked { return "already_unlocked" }
    if !o.displayAwake { return "display_asleep_unsupported" }
    if !o.accessibility || !o.eventPosting { return "permissions_missing" }
    if !o.targetVerified { return "secure_focus_unverified" }
    if !o.emptyField { return "empty_field_unverified" }
    return nil
}
public func sameSession(_ a: Observation, _ b: Observation) -> Bool {
    a.ownSession && b.ownSession && a.session != 0 && a.session == b.session
}
public struct Receipt: Codable {
    public let version: String
    public let schema: Int
    public let command: String
    public let result: String
    public let exitCode: Int32
    public let submitted: Bool
    public let recovered: Bool
    public let observation: Observation
    public init(command: String, result: String, exitCode: Int32, submitted: Bool = false, recovered: Bool = false, observation: Observation) {
        self.version = "0.1.0"; self.schema = 1; self.command = command; self.result = result; self.exitCode = exitCode
        self.submitted = submitted; self.recovered = recovered; self.observation = observation
    }
}
