import XCTest
import MultipeerConnectivity
@testable import ScreensaverTrivia

final class GameStoreTests: XCTestCase {
    @MainActor
    func testManualPauseSurvivesAppSwitchWhileAutomaticPauseResumes() async throws {
        var time = Date(timeIntervalSince1970: 1_000)
        let store = GameStore(startTimer: false, clock: { time })
        store.startSolo()
        let round = try XCTUnwrap(store.match?.round)
        time = round.startsAt.addingTimeInterval(2)
        store.tick(time)
        store.pauseSolo()
        let remaining = store.remaining
        store.setActive(false)
        time = time.addingTimeInterval(30)
        store.setActive(true)
        XCTAssertTrue(store.soloPaused, "App activation must not cancel the player's manual pause")
        XCTAssertEqual(store.remaining, remaining)
        store.resumeSolo()
        XCTAssertEqual(store.remaining, remaining, accuracy: 0.001)

        store.setActive(false)
        store.setActive(false) // inactive followed by background must retain pause ownership
        time = time.addingTimeInterval(20)
        store.setActive(true)
        XCTAssertFalse(store.soloPaused, "An automatic pause should resume on activation")
        XCTAssertEqual(store.remaining, remaining, accuracy: 0.001)
        store.leave()
    }

    @MainActor
    func testEarlyGuestTapIsUnlockedAndCanBeRetriedAfterHostStart() async throws {
        var time = Date(timeIntervalSince1970: 1_000)
        let hostTransport = NearbySession(networkingEnabled: false)
        let guestTransport = NearbySession(networkingEnabled: false)
        let host = GameStore(startTimer: false, transport: hostTransport, clock: { time })
        let guest = GameStore(startTimer: false, transport: guestTransport, clock: { time })
        defer {
            hostTransport.onSend = nil
            guestTransport.onSend = nil
            guest.leave()
            host.leave()
        }
        let hostPeer = MCPeerID(displayName: "retry-host")
        let guestPeer = MCPeerID(displayName: "retry-guest")
        hostTransport.onSend = { message, peers in
            if peers?.contains(guestPeer) ?? true { guestTransport.onMessage?(message, hostPeer) }
        }
        guestTransport.onSend = { message, peers in
            if peers?.contains(hostPeer) ?? true { hostTransport.onMessage?(message, guestPeer) }
        }
        host.hostParty()
        guest.findParty()
        guest.join(NearbyRoom(peer: hostPeer, name: "Host"))
        guestTransport.onConnection?(hostPeer, true)
        XCTAssertEqual(host.match?.players.count, 2)
        host.startMatch()
        let round = try XCTUnwrap(host.match?.round)
        // Simulate an overestimated guest clock allowing a tap before the host starts.
        guest.tick(round.startsAt)
        XCTAssertTrue(guest.canAnswer)
        guest.choose(round.locationID)
        XCTAssertNil(guest.selectedChoice, "The rejected early answer must not remain locked")
        XCTAssertFalse(guest.canAnswer)
        XCTAssertTrue(host.match?.answeredPlayerIDs.isEmpty ?? false)
        time = round.startsAt.addingTimeInterval(2)
        host.tick(time)
        guest.tick(time)
        guest.choose(round.locationID)
        XCTAssertEqual(host.match?.answeredPlayerIDs, [guest.localID])
        XCTAssertEqual(guest.selectedChoice, round.locationID)
        host.choose(round.locationID)
        XCTAssertEqual(guest.match?.stage, .reveal)
        XCTAssertEqual(guest.localPlayer?.score, 880)
        guest.leave()
        host.leave()
    }

    @MainActor
    func testDelayedRetryCannotUnlockAnAcceptedAnswerOrAnotherRound() async throws {
        var time = Date(timeIntervalSince1970: 1_000)
        let transport = NearbySession(networkingEnabled: false)
        let guest = GameStore(startTimer: false, transport: transport, clock: { time })
        let hostPeer = MCPeerID(displayName: "host")
        guest.findParty()
        guest.join(NearbyRoom(peer: hostPeer, name: "Host"))
        let host = Player(id: UUID(), name: "Host", avatar: 1)
        var snapshot = MatchSnapshot(matchID: UUID(), hostID: host.id,
            players: [host, Player(id: guest.localID, name: "Guest", avatar: 0)])
        let location = try XCTUnwrap(guest.catalog.locations.first)
        let round = GameRules.makeRound(location: location, allLocations: guest.catalog.locations,
            number: 1, startsAt: time, duration: 15)
        snapshot.stage = .round
        snapshot.round = round
        snapshot.revision = 1
        transport.onMessage?(.snapshot(snapshot), hostPeer)
        time = time.addingTimeInterval(1)
        guest.tick(time)
        guest.choose(round.locationID)
        let stale = GuessRetry(matchID: snapshot.matchID, roundID: UUID(),
            choiceID: round.locationID, hostTime: time)
        transport.onMessage?(.retryGuess(stale), hostPeer)
        XCTAssertEqual(guest.selectedChoice, round.locationID)
        snapshot.answeredPlayerIDs = [guest.localID]
        snapshot.revision = 2
        transport.onMessage?(.snapshot(snapshot), hostPeer)
        let alreadyAccepted = GuessRetry(matchID: snapshot.matchID, roundID: round.id,
            choiceID: round.locationID, hostTime: time)
        transport.onMessage?(.retryGuess(alreadyAccepted), hostPeer)
        XCTAssertEqual(guest.selectedChoice, round.locationID)
        guest.leave()
    }

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
