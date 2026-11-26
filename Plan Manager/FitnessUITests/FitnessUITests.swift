import XCTest

final class FitnessUITests: XCTestCase {
    @MainActor
    func testProfileEquipmentAndOfflineRecoveryPlan() throws {
        let app = XCUIApplication()
        app.launch()
        addUIInterruptionMonitor(withDescription: "Notifications") { alert in
            let allow = alert.buttons["Allow"]
            if allow.exists { allow.tap(); return true }
            let chinese = alert.buttons["允许"]
            if chinese.exists { chinese.tap(); return true }
            return false
        }
        app.tabBars.buttons["健身"].tap()
        app.tap()
        let profile = app.buttons["fitness.profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10)); profile.tap()
        let height = app.textFields["fitness.height"]
        height.tap(); height.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (height.value as? String)?.count ?? 0)); height.typeText("180")
        let weight = app.textFields["fitness.weight"]
        weight.tap(); weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (weight.value as? String)?.count ?? 0)); weight.typeText("81")
        app.buttons["fitness.profile.save"].tap()
        XCTAssertTrue(app.staticTexts["BMI 25.0"].waitForExistence(timeout: 5))
        app.buttons["fitness.equipment"].tap()
        app.buttons["fitness.equipment.add"].tap()
        app.textFields["fitness.equipment.name"].tap()
        app.textFields["fitness.equipment.name"].typeText("QA Chest Press")
        app.buttons["fitness.equipment.save"].tap()
        XCTAssertTrue(app.staticTexts["QA Chest Press"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()
        let pain = app.switches["有疼痛或受伤，暂停负重"]
        if !pain.isHittable { app.swipeUp() }
        if pain.value as? String != "1" { pain.tap() }
        let generate = app.buttons["fitness.generate"]
        for _ in 0..<4 where !generate.isHittable { app.swipeUp() }
        generate.tap()
        for _ in 0..<4 where !app.staticTexts["恢复日"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["恢复日"].waitForExistence(timeout: 5))
        app.terminate(); app.launch(); app.tabBars.buttons["健身"].tap()
        XCTAssertTrue(app.staticTexts["BMI 25.0"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["恢复日"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
    }
}
