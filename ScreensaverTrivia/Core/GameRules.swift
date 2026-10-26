import Foundation

enum GameRules {
    // Increment when either the offline pack or wire protocol becomes incompatible.
    static let catalogVersion = 2
    static let maximumPlayers = 8
    static let partyRevealDuration: TimeInterval = 8

    /// Correct answers earn 1,000 at the start, falling to 100 at the deadline.
    /// Wrong, non-finite and late answers earn zero. Time comes from the host.
    static func points(correct: Bool, elapsed: TimeInterval, duration: TimeInterval) -> Int {
        guard correct, elapsed.isFinite, duration.isFinite, duration > 0,
              elapsed >= 0, elapsed < duration else { return 0 }
        return max(100, Int((1_000 - 900 * elapsed / duration).rounded(.down)))
    }

    static func makeDeck(locations: [Location], collection: Collection, count: Int) -> [Location] {
        Array(locations.filter { $0.collectionIDs.contains(collection.rawValue) }
            .shuffled().prefix(max(0, count)))
    }

    static func makeRound(location: Location, allLocations: [Location], number: Int,
                          startsAt: Date, duration: TimeInterval) -> RoundPrompt {
        let distractors = allLocations.filter { $0.id != location.id }.shuffled().prefix(3)
        return RoundPrompt(id: UUID(), number: number, locationID: location.id,
                           choiceIDs: ([location.id] + distractors.map(\.id)).shuffled(),
                           startsAt: startsAt, duration: duration)
    }

    static func ranking(_ players: [Player]) -> [Player] {
        players.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.correctAnswers != $1.correctAnswers { return $0.correctAnswers > $1.correctAnswers }
            if $0.totalResponseTime != $1.totalResponseTime { return $0.totalResponseTime < $1.totalResponseTime }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    static func displayName(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !$0.isNewline && !$0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) }
        return clean.isEmpty ? "Explorer" : String(clean.prefix(16))
    }

    /// Validates a guess before any score or lock state can change.
    static func accepts(_ guess: GuessRequest, from playerID: UUID,
                        in match: MatchSnapshot, alreadyAnswered: Set<UUID>, now: Date) -> Bool {
        guard match.stage == .round, let round = match.round,
              guess.matchID == match.matchID, guess.roundID == round.id,
              round.choiceIDs.contains(guess.choiceID),
              match.players.contains(where: { $0.id == playerID && $0.isConnected }),
              !alreadyAnswered.contains(playerID), now >= round.startsAt, now < round.deadline
        else { return false }
        return true
    }
}
