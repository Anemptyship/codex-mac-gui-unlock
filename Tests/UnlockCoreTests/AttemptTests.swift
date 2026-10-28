import XCTest
@testable import UnlockCore

final class AttemptTests: XCTestCase {
    func ready() -> Observation {
        var o = Observation(); o.ownSession = true; o.session = 42; o.state = .locked
        o.displayAwake = true; o.accessibility = true; o.eventPosting = true
        o.targetVerified = true; o.emptyField = true; return o
    }
    func testDeniedGuardsNeverReadCredentialOrSubmit() {
        let changes: [(inout Observation) -> Void] = [
            { $0.ownSession = false }, { $0.state = .unknown }, { $0.state = .unlocked },
            { $0.accessibility = false }, { $0.eventPosting = false }, { $0.displayAwake = false },
            { $0.targetVerified = false }, { $0.emptyField = false }
        ]
        for change in changes {
            var o = ready(); change(&o)
            let result = attemptOnce(observation: o, validateTarget: { XCTFail("target not needed"); return true },
                readSecret: { XCTFail("must not read secret"); return nil },
                post: { _ in XCTFail("must not post input"); return InputOutcome(emitted: false, complete: false) },
                verify: { XCTFail("nothing to verify"); return false })
            XCTAssertFalse(result.submitted); XCTAssertFalse(result.recovered)
        }
    }
    func testMissingOrRevokedCredentialStops() {
        let r = attemptOnce(observation: ready(), validateTarget: { true }, readSecret: { nil },
            post: { _ in XCTFail("credential absent"); return InputOutcome(emitted: false, complete: false) }, verify: { false })
        XCTAssertEqual(r.reason, "credential_absent_or_access_denied")
    }
    func testFocusLossAfterCredentialReadStops() {
        var checks = 0
        let r = attemptOnce(observation: ready(), validateTarget: { checks += 1; return checks == 1 },
            readSecret: { Data([1,2,3]) }, post: { _ in XCTFail("focus lost"); return InputOutcome(emitted: false, complete: false) }, verify: { false })
        XCTAssertEqual(r.reason, "focus_changed"); XCTAssertFalse(r.submitted)
    }
    func testPartialInputAndUnknownUnlockNeverRetry() {
        for complete in [false, true] {
            var reads = 0, posts = 0, verifications = 0
            let r = attemptOnce(observation: ready(), validateTarget: { true }, readSecret: { reads += 1; return Data([1]) },
                post: { _ in posts += 1; return InputOutcome(emitted: true, complete: complete) },
                verify: { verifications += 1; return false })
            XCTAssertEqual(reads, 1); XCTAssertEqual(posts, 1)
            XCTAssertEqual(verifications, complete ? 1 : 0); XCTAssertEqual(r.code, 3); XCTAssertFalse(r.recovered)
        }
    }
    func testSuccessRequiresIndependentVerification() {
        var verified = false
        let r = attemptOnce(observation: ready(), validateTarget: { true }, readSecret: { Data([1]) },
            post: { _ in InputOutcome(emitted: true, complete: true) }, verify: { verified = true; return true })
        XCTAssertTrue(verified); XCTAssertTrue(r.recovered); XCTAssertTrue(r.submitted)
    }
}
