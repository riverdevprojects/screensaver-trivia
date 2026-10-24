import XCTest
@testable import ScreensaverTrivia

final class GameRulesTests: XCTestCase {
    func testEarlyGuessRetrySurvivesWireEncoding() throws {
        let retry = GuessRetry(matchID: UUID(), roundID: UUID(), choiceID: "paris",
            hostTime: Date(timeIntervalSince1970: 1_000))
        let data = try JSONEncoder().encode(WireMessage.retryGuess(retry))
        guard case .retryGuess(let decoded) = try JSONDecoder().decode(WireMessage.self, from: data) else {
            return XCTFail("Wrong wire message")
        }
        XCTAssertEqual(decoded.matchID, retry.matchID)
        XCTAssertEqual(decoded.roundID, retry.roundID)
        XCTAssertEqual(decoded.choiceID, retry.choiceID)
        XCTAssertEqual(decoded.hostTime, retry.hostTime)
    }

    func testScoringRewardsSpeedAndRejectsInvalidOrLateAnswers() {
        XCTAssertEqual(GameRules.points(correct: true, elapsed: 0, duration: 15), 1_000)
        XCTAssertEqual(GameRules.points(correct: true, elapsed: 7.5, duration: 15), 550)
        XCTAssertEqual(GameRules.points(correct: true, elapsed: 14.999, duration: 15), 100)
        XCTAssertEqual(GameRules.points(correct: false, elapsed: 0, duration: 15), 0)
        for elapsed in [-1.0, 15, 16, .infinity, .nan] {
            XCTAssertEqual(GameRules.points(correct: true, elapsed: elapsed, duration: 15), 0)
        }
        XCTAssertEqual(GameRules.points(correct: true, elapsed: 1, duration: 0), 0)
    }

    func testPointsNeverIncreaseAsAnswerGetsLater() {
        let scores = (0..<150).map { GameRules.points(correct: true, elapsed: Double($0) / 10, duration: 15) }
        XCTAssertTrue(zip(scores, scores.dropFirst()).allSatisfy { $0 >= $1 })
    }

    func testRoundAlwaysHasFourUniqueChoicesIncludingCorrectPlace() throws {
        let locations = try loadLocations()
        for location in locations {
            for _ in 0..<30 {
                let round = GameRules.makeRound(location: location, allLocations: locations,
                    number: 1, startsAt: Date(), duration: 15)
                XCTAssertEqual(round.choiceIDs.count, 4)
                XCTAssertEqual(Set(round.choiceIDs).count, 4)
                XCTAssertTrue(round.choiceIDs.contains(location.id))
                XCTAssertEqual(round.locationID, location.id)
            }
        }
    }

    func testDeckFiltersCollectionsWithoutRepeatingLocations() throws {
        let locations = try loadLocations()
        for collection in Collection.allCases {
            let deck = GameRules.makeDeck(locations: locations, collection: collection, count: 100)
            XCTAssertFalse(deck.isEmpty)
            XCTAssertEqual(Set(deck.map(\.id)).count, deck.count)
            XCTAssertTrue(deck.allSatisfy { $0.collectionIDs.contains(collection.rawValue) })
            XCTAssertLessThanOrEqual(GameRules.makeDeck(locations: locations, collection: collection, count: 5).count, 5)
        }
    }

    func testGuessesRejectDuplicatesStaleRoundsUnknownPlayersAndExpiredTimers() {
        let player = Player(id: UUID(), name: "River", avatar: 0)
        let start = Date(timeIntervalSince1970: 1_000)
        let round = RoundPrompt(id: UUID(), number: 1, locationID: "paris",
            choiceIDs: ["paris", "sydney", "london", "dubai"], startsAt: start, duration: 15)
        var match = MatchSnapshot(matchID: UUID(), hostID: player.id, players: [player])
        match.stage = .round
        match.round = round
        let guess = GuessRequest(matchID: match.matchID, roundID: round.id, choiceID: "paris")
        func accepts(_ request: GuessRequest? = nil, playerID: UUID? = nil,
                     answered: Set<UUID> = [], at time: TimeInterval = 1_005) -> Bool {
            GameRules.accepts(request ?? guess, from: playerID ?? player.id, in: match,
                alreadyAnswered: answered, now: Date(timeIntervalSince1970: time))
        }
        XCTAssertTrue(accepts())
        XCTAssertFalse(accepts(answered: [player.id]))
        XCTAssertFalse(accepts(playerID: UUID()))
        XCTAssertFalse(accepts(at: 999))
        XCTAssertFalse(accepts(at: 1_015))
        XCTAssertFalse(accepts(GuessRequest(matchID: UUID(), roundID: round.id, choiceID: "paris")))
        XCTAssertFalse(accepts(GuessRequest(matchID: match.matchID, roundID: UUID(), choiceID: "paris")))
        XCTAssertFalse(accepts(GuessRequest(matchID: match.matchID, roundID: round.id, choiceID: "unknown")))
        match.stage = .reveal
        XCTAssertFalse(accepts())
        match.stage = .round
        match.players[0].isConnected = false
        XCTAssertFalse(accepts())
    }

    func testRankingUsesScoreThenAccuracyThenSpeed() {
        let slow = Player(id: UUID(), name: "Slow", avatar: 0, score: 500, correctAnswers: 2, totalResponseTime: 10)
        let fast = Player(id: UUID(), name: "Fast", avatar: 1, score: 500, correctAnswers: 2, totalResponseTime: 5)
        let accurate = Player(id: UUID(), name: "Accurate", avatar: 2, score: 500, correctAnswers: 3, totalResponseTime: 15)
        let winner = Player(id: UUID(), name: "Winner", avatar: 3, score: 800, correctAnswers: 1)
        XCTAssertEqual(GameRules.ranking([slow, winner, fast, accurate]).map(\.name), ["Winner", "Accurate", "Fast", "Slow"])
    }

    func testWireMessagesRoundTripWithoutLosingIdentifiersOrDates() throws {
        let player = Player(id: UUID(), name: "Explorer", avatar: 2)
        var snapshot = MatchSnapshot(matchID: UUID(), hostID: player.id, players: [player])
        snapshot.round = RoundPrompt(id: UUID(), number: 1, locationID: "paris",
            choiceIDs: ["paris", "sydney", "london", "dubai"], startsAt: Date(), duration: 15)
        let data = try JSONEncoder().encode(WireMessage.snapshot(snapshot))
        guard case .snapshot(let decoded) = try JSONDecoder().decode(WireMessage.self, from: data) else {
            return XCTFail("Wrong wire message")
        }
        XCTAssertEqual(decoded, snapshot)
    }

    func testNamesAreBoundedAndHaveSafeFallbacks() {
        XCTAssertEqual(GameRules.displayName("  River  "), "River")
        XCTAssertEqual(GameRules.displayName(" \n "), "Explorer")
        XCTAssertEqual(GameRules.displayName(String(repeating: "🌍", count: 50)).count, 16)
        XCTAssertEqual(GameRules.displayName("Ri\nver"), "River")
    }

    func testEveryLocationHasBundledVideoPosterAndAttribution() throws {
        let locations = try loadLocations()
        XCTAssertEqual(locations.count, 6)
        XCTAssertEqual(Set(locations.map(\.id)).count, locations.count)
        for location in locations {
            let video = try XCTUnwrap(LocationCatalog.mediaURL(location.id, extension: "mp4"))
            XCTAssertGreaterThan(try Data(contentsOf: video).count, 50_000)
            XCTAssertNotNil(LocationCatalog.mediaURL(location.id, extension: "jpg"))
            XCTAssertTrue(location.sourceURL.hasPrefix("https://"))
            XCTAssertFalse(location.author.isEmpty)
            XCTAssertFalse(location.license.isEmpty)
        }
    }

    private func loadLocations() throws -> [Location] {
        let catalog = LocationCatalog()
        XCTAssertNil(catalog.error)
        return try XCTUnwrap(catalog.locations.isEmpty ? nil : catalog.locations)
    }
}
