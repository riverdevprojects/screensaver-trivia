import Foundation

struct Location: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let country: String
    let detail: String
    let collectionIDs: [String]
    let sourceTitle: String
    let sourceURL: String
    let author: String
    let license: String
    let licenseURL: String
}

enum Collection: String, CaseIterable, Codable, Identifiable {
    case world, cities, waterfront
    var id: String { rawValue }
    var title: String {
        switch self {
        case .world: return "World tour"
        case .cities: return "City lights"
        case .waterfront: return "By the water"
        }
    }
    var symbol: String {
        switch self {
        case .world: return "globe.americas.fill"
        case .cities: return "building.2.fill"
        case .waterfront: return "water.waves"
        }
    }
}

struct Player: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var avatar: Int
    var score = 0
    var correctAnswers = 0
    var totalResponseTime: TimeInterval = 0
    var isConnected = true
}

struct RoundPrompt: Codable, Equatable, Identifiable {
    let id: UUID
    let number: Int
    let locationID: String
    let choiceIDs: [String]
    let startsAt: Date
    let duration: TimeInterval
    var deadline: Date { startsAt.addingTimeInterval(duration) }
}

struct Answer: Codable, Equatable {
    let playerID: UUID
    let roundID: UUID
    let choiceID: String
    let elapsed: TimeInterval
    let points: Int
}

enum MatchStage: String, Codable {
    case lobby, round, reveal, finished
}

struct MatchSnapshot: Codable, Equatable {
    let matchID: UUID
    let hostID: UUID
    var revision: Int = 0
    var stage: MatchStage = .lobby
    var players: [Player]
    var collection: Collection = .world
    var roundCount: Int = 5
    var round: RoundPrompt?
    // Host-clock deadline shared by every player during a party reveal.
    var revealEndsAt: Date?
    var answers: [Answer] = []
    // Only populated after reveal. During play the ribbon shows locks, not correctness.
    var answeredPlayerIDs: [UUID] = []
}

struct JoinRequest: Codable { let player: Player; let catalogVersion: Int }
struct GuessRequest: Codable { let matchID: UUID; let roundID: UUID; let choiceID: String }
struct GuessRetry: Codable {
    let matchID: UUID
    let roundID: UUID
    let choiceID: String
    let hostTime: Date
}
struct ClockProbe: Codable { let id: UUID; let sentAt: Date }
struct ClockReply: Codable { let id: UUID; let sentAt: Date; let hostTime: Date }

enum WireMessage: Codable {
    case join(JoinRequest)
    case snapshot(MatchSnapshot)
    case guess(GuessRequest)
    case retryGuess(GuessRetry)
    case probe(ClockProbe)
    case clock(ClockReply)
    case leave
    case ended(String)
}

struct GameSettings: Codable, Equatable {
    var name = "Explorer"
    var avatar = 0
    var roundCount = 5
    var duration: TimeInterval = 15
    var haptics = true
    var collection: Collection = .world
}

struct PersonalStats: Codable {
    var bestScore = 0
    var gamesPlayed = 0
    var locationsGuessed = 0
}
