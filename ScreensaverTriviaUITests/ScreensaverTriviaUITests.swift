import XCTest

final class ScreensaverTriviaUITests: XCTestCase {
    func testPartyLobbyWaitsForFriends() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["playParty"].tap()
        app.buttons["Host a party"].tap()
        XCTAssertTrue(app.buttons["startParty"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["startParty"].isEnabled)
        screenshot("05-party-lobby")
    }

    func testSoloTourFromHomeThroughResultsAndReplay() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["playSolo"].waitForExistence(timeout: 10))
        screenshot("01-home")
        app.buttons["playSolo"].tap()
        XCTAssertTrue(app.buttons["answer0"].waitForExistence(timeout: 5))
        screenshot("02-round")
        for index in 0..<5 {
            let answer = app.buttons["answer0"]
            XCTAssertTrue(answer.waitForExistence(timeout: 5))
            answer.tap()
            XCTAssertTrue(app.buttons["nextRound"].waitForExistence(timeout: 5))
            if index == 0 { screenshot("03-reveal") }
            app.buttons["nextRound"].tap()
        }
        XCTAssertTrue(app.buttons["playAgain"].waitForExistence(timeout: 5))
        screenshot("04-podium")
        app.buttons["playAgain"].tap()
        XCTAssertTrue(app.buttons["answer0"].waitForExistence(timeout: 5))
    }

    func testSettingsAndPauseResume() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["settings"].tap()
        XCTAssertTrue(app.textFields["playerName"].waitForExistence(timeout: 5))
        app.buttons["saveSettings"].tap()
        app.buttons["playSolo"].tap()
        XCTAssertTrue(app.buttons["pauseGame"].waitForExistence(timeout: 5))
        app.buttons["pauseGame"].tap()
        XCTAssertTrue(app.buttons["Keep exploring"].waitForExistence(timeout: 5))
        app.buttons["Keep exploring"].tap()
        XCTAssertTrue(app.buttons["answer0"].isEnabled)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
