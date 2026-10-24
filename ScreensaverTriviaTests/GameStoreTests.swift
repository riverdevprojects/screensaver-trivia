import XCTest
@testable import ScreensaverTrivia

final class GameStoreTests: XCTestCase {
    @MainActor
    func testCompleteSoloMatchScoresOnlyOnceAndRecordsStats() async throws {
        let suite = "ScreensaverTriviaTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = GameStore(defaults: defaults, startTimer: false)
        store.startSolo()
        XCTAssertEqual(store.screen, .game)
        for number in 1...5 {
            let round = try XCTUnwrap(store.match?.round)
            XCTAssertEqual(round.number, number)
            store.tick(round.startsAt.addingTimeInterval(3))
            store.choose(round.locationID)
            XCTAssertEqual(store.match?.stage, .reveal)
            let score = store.localPlayer?.score
            store.choose(round.locationID)
            XCTAssertEqual(store.localPlayer?.score, score, "Repeated input must not score twice")
            store.nextRound()
        }
        XCTAssertEqual(store.screen, .results)
        XCTAssertEqual(store.localPlayer?.score, 4_100)
        XCTAssertEqual(store.stats.gamesPlayed, 1)
        XCTAssertEqual(store.stats.locationsGuessed, 5)
        store.nextRound()
        XCTAssertEqual(store.stats.gamesPlayed, 1)
        store.leave()
        XCTAssertEqual(store.screen, .home)
        XCTAssertNil(store.match)
    }

    @MainActor
    func testTimeoutRevealsWithoutPointsAndRejectsLateTap() async throws {
        let store = GameStore(startTimer: false)
        store.startSolo()
        let round = try XCTUnwrap(store.match?.round)
        store.tick(round.deadline)
        XCTAssertEqual(store.match?.stage, .reveal)
        XCTAssertEqual(store.localPlayer?.score, 0)
        XCTAssertTrue(store.match?.answers.isEmpty ?? false)
        store.choose(round.locationID)
        XCTAssertEqual(store.localPlayer?.score, 0)
        store.leave()
    }

    @MainActor
    func testPreCountdownTapIsIgnoredAndSoloPauseFreezesClock() async throws {
        let store = GameStore(startTimer: false)
        store.startSolo()
        let round = try XCTUnwrap(store.match?.round)
        // Test the countdown explicitly even when the UI runner skips countdowns.
        store.tick(round.startsAt.addingTimeInterval(-1))
        store.choose(round.locationID)
        XCTAssertNil(store.selectedChoice)
        store.tick(round.startsAt.addingTimeInterval(2))
        store.pauseSolo()
        let remaining = store.remaining
        store.tick(round.deadline.addingTimeInterval(50))
        XCTAssertEqual(store.remaining, remaining)
        XCTAssertEqual(store.match?.stage, .round)
        store.resumeSolo()
        XCTAssertFalse(store.soloPaused)
        store.leave()
    }

    @MainActor
    func testReplayResetsScoresAndStartsFreshMatch() async throws {
        let store = GameStore(startTimer: false)
        store.startSolo()
        let oldID = store.match?.matchID
        for _ in 0..<5 {
            let round = try XCTUnwrap(store.match?.round)
            store.tick(round.deadline)
            store.nextRound()
        }
        store.playAgain()
        XCTAssertNotEqual(store.match?.matchID, oldID)
        XCTAssertEqual(store.match?.round?.number, 1)
        XCTAssertEqual(store.localPlayer?.score, 0)
        XCTAssertNil(store.selectedChoice)
        store.leave()
    }
}
