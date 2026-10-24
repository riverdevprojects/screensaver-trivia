import XCTest
import MultipeerConnectivity
@testable import ScreensaverTrivia

final class GameStoreTests: XCTestCase {
    @MainActor
    func testHostWaitsForAllPlayersAndScoresEachGuessOnce() async throws {
        var time = Date(timeIntervalSince1970: 1_000)
        let transport = NearbySession(networkingEnabled: false)
        let store = GameStore(startTimer: false, transport: transport, clock: { time })
        store.hostParty()
        let first = Player(id: UUID(), name: "First guest", avatar: 1)
        let second = Player(id: UUID(), name: "Second guest", avatar: 2)
        let peerA = MCPeerID(displayName: "guest-a")
        let peerB = MCPeerID(displayName: "guest-b")
        transport.onMessage?(.join(JoinRequest(player: first, catalogVersion: GameRules.catalogVersion)), peerA)
        transport.onMessage?(.join(JoinRequest(player: second, catalogVersion: GameRules.catalogVersion)), peerB)
        XCTAssertEqual(store.match?.players.count, 3)
        store.startMatch()
        let matchID = try XCTUnwrap(store.match?.matchID)
        let round = try XCTUnwrap(store.match?.round)
        time = round.startsAt.addingTimeInterval(2)
        store.tick(time)
        store.choose(round.locationID)
        XCTAssertEqual(store.match?.stage, .round)
        XCTAssertTrue(store.match?.answers.isEmpty ?? false, "Correctness must stay hidden while others answer")
        time = round.startsAt.addingTimeInterval(3)
        let correct = GuessRequest(matchID: matchID, roundID: round.id, choiceID: round.locationID)
        transport.onMessage?(.guess(correct), peerA)
        transport.onMessage?(.guess(correct), peerA)
        XCTAssertEqual(store.match?.answeredPlayerIDs.count, 2)
        XCTAssertTrue(store.match?.players.allSatisfy { $0.score == 0 } ?? false)
        time = round.startsAt.addingTimeInterval(5)
        let wrong = try XCTUnwrap(round.choiceIDs.first { $0 != round.locationID })
        transport.onMessage?(.guess(GuessRequest(matchID: matchID, roundID: round.id, choiceID: wrong)), peerB)
        XCTAssertEqual(store.match?.stage, .reveal)
        XCTAssertEqual(store.localPlayer?.score, 880)
        XCTAssertEqual(store.match?.players.first { $0.id == first.id }?.score, 820)
        XCTAssertEqual(store.match?.players.first { $0.id == second.id }?.score, 0)
        XCTAssertEqual(store.match?.answers.count, 3)

        store.nextRound()
        let next = try XCTUnwrap(store.match?.round)
        transport.onMessage?(.guess(correct), peerA)
        XCTAssertEqual(store.match?.answeredPlayerIDs.count, 0, "Previous-round packets cannot lock the new round")
        transport.onConnection?(peerA, false)
        transport.onConnection?(peerB, false)
        time = next.startsAt.addingTimeInterval(1)
        store.tick(time)
        store.choose(next.locationID)
        XCTAssertEqual(store.match?.stage, .reveal, "Disconnected players must not block reveal")
        store.leave()
    }

    @MainActor
    func testGuestUsesHostSnapshotsAndIgnoresStaleRevisions() async throws {
        var time = Date(timeIntervalSince1970: 1_000)
        let transport = NearbySession(networkingEnabled: false)
        let store = GameStore(startTimer: false, transport: transport, clock: { time })
        store.findParty()
        let peer = MCPeerID(displayName: "host")
        store.join(NearbyRoom(peer: peer, name: "Host"))
        transport.onConnection?(peer, true)
        let host = Player(id: UUID(), name: "Host", avatar: 1)
        var snapshot = MatchSnapshot(matchID: UUID(), hostID: host.id,
            players: [host, Player(id: store.localID, name: "Guest", avatar: 0)])
        snapshot.revision = 1
        transport.onMessage?(.snapshot(snapshot), peer)
        XCTAssertFalse(store.isJoining)
        XCTAssertEqual(store.screen, .lobby)
        let location = try XCTUnwrap(store.catalog.locations.first)
        let round = GameRules.makeRound(location: location, allLocations: store.catalog.locations,
            number: 1, startsAt: time, duration: 15)
        snapshot.stage = .round
        snapshot.round = round
        snapshot.revision = 2
        transport.onMessage?(.snapshot(snapshot), peer)
        time = time.addingTimeInterval(2)
        store.tick(time)
        store.choose(round.locationID)
        XCTAssertEqual(store.selectedChoice, round.locationID)
        XCTAssertEqual(store.localPlayer?.score, 0, "Guests cannot award their own points")
        snapshot.stage = .reveal
        snapshot.revision = 3
        snapshot.players[1].score = 880
        transport.onMessage?(.snapshot(snapshot), peer)
        XCTAssertEqual(store.localPlayer?.score, 880)
        snapshot.revision = 2
        snapshot.players[1].score = 0
        transport.onMessage?(.snapshot(snapshot), peer)
        XCTAssertEqual(store.localPlayer?.score, 880)
        transport.onConnection?(peer, false)
        XCTAssertEqual(store.screen, .home)
        XCTAssertNil(store.match)
        XCTAssertNotNil(store.alert)
    }

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
