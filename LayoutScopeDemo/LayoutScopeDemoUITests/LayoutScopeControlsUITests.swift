import XCTest

final class LayoutScopeControlsUITests: XCTestCase {
    @MainActor
    func testEveryToggleChangesState() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let readout = app.switches["Readout"]
        XCTAssertTrue(readout.waitForExistence(timeout: 10))
        XCTAssertFalse(app.switches["Hinge"].exists)
        for label in ["Safe areas", "Occlusions", "Divisions", "Include inactive", "Readout"] {
            let toggle = app.switches[label]
            XCTAssertTrue(toggle.exists, "Missing toggle: \(label)")
            XCTAssertEqual(toggle.value as? String, "1")
            toggle.switches.firstMatch.tap()
            XCTAssertEqual(toggle.value as? String, "0")
            toggle.switches.firstMatch.tap()
            XCTAssertEqual(toggle.value as? String, "1")
        }
    }
}
