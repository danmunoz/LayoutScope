import XCTest

final class LayoutScopeControlsUITests: XCTestCase {
    @MainActor
    func testEveryVisibilityToggleChangesState() {
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

    @MainActor
    func testPanelCanCollapseReopenAndBeHiddenByReadoutSwitch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        let header = app.buttons["layoutScope.readout.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        XCTAssertEqual(header.value as? String, "Expanded")
        header.tap()
        XCTAssertEqual(header.value as? String, "Collapsed")
        XCTAssertFalse(app.staticTexts["layoutScope.readout.context"].exists)

        header.tap()
        XCTAssertEqual(header.value as? String, "Expanded")
        XCTAssertTrue(app.staticTexts["layoutScope.readout.context"].exists)

        let readoutSwitch = app.switches["Readout"]
        readoutSwitch.switches.firstMatch.tap()
        XCTAssertEqual(readoutSwitch.value as? String, "0")
        XCTAssertFalse(header.exists)
        readoutSwitch.switches.firstMatch.tap()
        XCTAssertTrue(header.waitForExistence(timeout: 5))
    }

    @MainActor
    func testContentControlsRemainTouchableBehindOverlay() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        let header = app.buttons["layoutScope.readout.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        let showOverlay = app.switches["Show overlay"]
        XCTAssertTrue(showOverlay.exists)
        showOverlay.switches.firstMatch.tap()
        XCTAssertFalse(header.exists)
        showOverlay.switches.firstMatch.tap()
        XCTAssertTrue(header.waitForExistence(timeout: 5))
    }

    @MainActor
    func testDivisionExpansionKeepsGeometryVisibleAndShowsDetails() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let division = app.buttons["layoutScope.readout.division.1.toggle"]
        guard division.waitForExistence(timeout: 5) else {
            throw XCTSkip("Live division values require an iOS 27.1 Duo runtime")
        }

        let regionRow = app.descendants(matching: .any)["layoutScope.readout.region.division.1"]
        let origin = app.staticTexts["layoutScope.readout.region.division.1.origin"]
        let size = app.staticTexts["layoutScope.readout.region.division.1.size"]
        XCTAssertTrue(regionRow.exists)
        XCTAssertTrue(origin.exists)
        XCTAssertTrue(size.exists)
        let originalOrigin = origin.label
        let originalSize = size.label
        division.tap()
        XCTAssertEqual(division.value as? String, "Expanded")
        XCTAssertTrue(app.descendants(matching: .any)["layoutScope.readout.division.1.side.1"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["layoutScope.readout.division.1.side.2"].exists)
        XCTAssertTrue(regionRow.exists, "The division's origin and size row stays visible when details expand")
        XCTAssertEqual(origin.label, originalOrigin)
        XCTAssertEqual(size.label, originalSize)
        XCTAssertFalse(app.buttons["layoutScope.readout.occlusion.1.toggle"].exists)

        app.switches["Readout"].switches.firstMatch.tap()
        app.switches["Readout"].switches.firstMatch.tap()
        XCTAssertEqual(division.value as? String, "Expanded", "Readout visibility preserves division disclosure state")
        division.tap()
        XCTAssertEqual(division.value as? String, "Collapsed")
        XCTAssertEqual(origin.label, originalOrigin)
        XCTAssertEqual(size.label, originalSize)
        XCTAssertFalse(app.descendants(matching: .any)["layoutScope.readout.division.1.details"].exists)
    }
}
