import XCTest
@testable import UnlockCore

final class PolicyTests: XCTestCase {
    func ready() -> Observation {
        var o = Observation(); o.ownSession = true; o.session = 42; o.state = .locked
        o.accessibility = true; o.eventPosting = true; o.displayAwake = true
        o.targetVerified = true; o.emptyField = true; return o
    }
    func testReady() { XCTAssertNil(refusal(ready())) }
    func testEveryMissingGuardRefuses() {
        let changes: [(inout Observation) -> Void] = [
            { $0.ownSession = false }, { $0.state = .unknown }, { $0.accessibility = false },
            { $0.eventPosting = false }, { $0.displayAwake = false },
            { $0.targetVerified = false }, { $0.emptyField = false }
        ]
        for change in changes { var o = ready(); change(&o); XCTAssertNotNil(refusal(o)) }
    }
    func testAlreadyUnlockedIsNoop() {
        var o = ready(); o.state = .unlocked
        XCTAssertEqual(refusal(o), "already_unlocked")
        let receipt = Receipt(command: "unlock-once", result: "already_unlocked", exitCode: 0, observation: o)
        XCTAssertFalse(receipt.recovered); XCTAssertFalse(receipt.submitted)
    }
    func testSessionChanges() {
        let first = ready(); var second = first; second.session = 43
        XCTAssertFalse(sameSession(first, second))
        second = first; second.ownSession = false; XCTAssertFalse(sameSession(first, second))
    }
    func testGrantBoundToTaskSessionUserAndTime() {
        let now = Date(timeIntervalSince1970: 1000), task = UUID(), o = ready()
        var grant = Grant(task: task, session: 42, uid: 501, now: now, uptime: 500)
        func permits(_ t: UUID = task, _ observation: Observation = o, _ uid: UInt32 = 501, _ date: Date = now, _ uptime: Double = 500) -> Bool {
            grant.permits(task: t, observation: observation, uid: uid, now: date, uptime: uptime)
        }
        XCTAssertTrue(permits()); XCTAssertFalse(permits(UUID()))
        XCTAssertFalse(permits(task, o, 502))
        var changed = o; changed.session = 43; XCTAssertFalse(permits(task, changed))
        XCTAssertFalse(permits(task, o, 501, now.addingTimeInterval(120)))
        XCTAssertFalse(permits(task, o, 501, now, 620))
        XCTAssertFalse(permits(task, o, 501, now, 499))
        XCTAssertFalse(permits(task, o, 501, now.addingTimeInterval(-1)))
        grant.used = true; XCTAssertFalse(permits())
    }
    func testReceiptHasOnlyFixedMetadata() throws {
        let receipt = Receipt(command: "preflight", result: "ready", exitCode: 0, observation: ready())
        let data = try JSONEncoder().encode(receipt)
        let decoded = try JSONDecoder().decode(Receipt.self, from: data)
        XCTAssertEqual(decoded.version, "0.1.0"); XCTAssertFalse(decoded.recovered)
        let keys = Set((try JSONSerialization.jsonObject(with: data) as! [String:Any]).keys)
        XCTAssertEqual(keys, Set(["version","schema","command","result","exitCode","submitted","recovered","observation"]))
    }
}
