import Foundation
import Combine
import MultipeerConnectivity
import UIKit

enum Screen: Equatable { case home, lobby, game, results }

@MainActor
final class GameStore: ObservableObject {
    @Published var screen: Screen = .home
    @Published private(set) var match: MatchSnapshot?
    @Published private(set) var now = Date()
    @Published private(set) var selectedChoice: String?
    @Published var settings: GameSettings
    @Published private(set) var stats: PersonalStats
    @Published var alert: String?
    @Published private(set) var isJoining = false
    @Published private(set) var soloPaused = false

    let nearby: NearbySession
    let catalog = LocationCatalog()
    let localID = UUID()
    private(set) var isHost = true
    private(set) var isParty = false
    private let defaults: UserDefaults
    private let clock: () -> Date
    private var timer: AnyCancellable?
    private var deck: [Location] = []
    private var roundAnswers: [UUID: Answer] = [:]
    private var peerPlayers: [MCPeerID: UUID] = [:]
    private var hostPeer: MCPeerID?
    private var clockOffset: TimeInterval = 0
    private var bestRoundTrip = TimeInterval.infinity
    private var completedMatches: Set<UUID> = []
    private var joinTimeout: Task<Void, Never>?
    private var pauseStartedAt: Date?
    private var sceneActive = true

    init(defaults: UserDefaults = .standard, startTimer: Bool = true,
         transport: NearbySession? = nil, clock: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.clock = clock
        nearby = transport ?? NearbySession(networkingEnabled: !Self.isUITesting)
        settings = defaults.data(forKey: "settings").flatMap { try? JSONDecoder().decode(GameSettings.self, from: $0) } ?? GameSettings()
        stats = defaults.data(forKey: "stats").flatMap { try? JSONDecoder().decode(PersonalStats.self, from: $0) } ?? PersonalStats()
        now = clock()
        nearby.onMessage = { [weak self] message, peer in self?.receive(message, from: peer) }
        nearby.onConnection = { [weak self] peer, connected in self?.connection(peer, connected: connected) }
        nearby.onError = { [weak self] message in self?.alert = message }
        if startTimer {
            timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
                .sink { [weak self] date in self?.tick(date) }
        }
    }

    var localPlayer: Player? { match?.players.first { $0.id == localID } }
    var remaining: TimeInterval {
        guard let round = match?.round else { return 0 }
        return max(0, min(round.duration, round.deadline.timeIntervalSince(now)))
    }
    var countdown: Int {
        guard let round = match?.round else { return 0 }
        return max(0, Int(ceil(round.startsAt.timeIntervalSince(now))))
    }
    var canAnswer: Bool {
        match?.stage == .round && countdown == 0 && remaining > 0 && selectedChoice == nil && !soloPaused
    }
    var availableRounds: Int { min(settings.roundCount, catalog.count(in: settings.collection)) }

    func saveSettings() {
        settings.name = GameRules.displayName(settings.name)
        settings.avatar = min(7, max(0, settings.avatar))
        settings.roundCount = [5, 8].contains(settings.roundCount) ? settings.roundCount : 5
        settings.duration = [10.0, 15.0, 20.0].contains(settings.duration) ? settings.duration : 15
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: "settings") }
        if isHost, screen == .lobby { updateLobby() }
    }

    func startSolo() {
        leave()
        guard validateCatalog() else { return }
        isHost = true
        isParty = false
        match = makeLobby()
        startMatch()
    }

    func hostParty() {
        leave()
        guard validateCatalog() else { return }
        saveSettings()
        isHost = true
        isParty = true
        match = makeLobby()
        screen = .lobby
        nearby.host(name: settings.name)
    }

    func findParty() {
        leave()
        guard validateCatalog() else { return }
        saveSettings()
        isHost = false
        isParty = true
        screen = .lobby
        nearby.browse()
    }

    func join(_ room: NearbyRoom) {
        guard !isJoining, match == nil else { return }
        hostPeer = room.peer
        isJoining = true
        nearby.join(room)
        joinTimeout?.cancel()
        joinTimeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 18_000_000_000)
            guard !Task.isCancelled, let self, self.isJoining else { return }
            self.findParty()
            self.alert = "The party didn’t respond. Make sure both devices are on the same Wi-Fi network, then try again."
        }
    }

    func updateLobby() {
        guard isHost, var match, match.stage == .lobby else { return }
        match.collection = settings.collection
        match.roundCount = availableRounds
        if let index = match.players.firstIndex(where: { $0.id == localID }) {
            match.players[index].name = settings.name
            match.players[index].avatar = settings.avatar
        }
        self.match = match
        broadcast()
    }

    func startMatch() {
        guard isHost, var match, match.stage == .lobby else { return }
        if isParty && match.players.filter(\.isConnected).count < 2 { return }
        deck = GameRules.makeDeck(locations: catalog.locations, collection: match.collection, count: match.roundCount)
        guard !deck.isEmpty else { return }
        match.roundCount = deck.count
        self.match = match
        nearby.acceptingInvites = false
        nearby.stopAdvertising()
        beginRound(number: 1)
    }

    func choose(_ choiceID: String) {
        guard canAnswer, let match, let round = match.round else { return }
        let request = GuessRequest(matchID: match.matchID, roundID: round.id, choiceID: choiceID)
        guard round.choiceIDs.contains(choiceID) else { return }
        selectedChoice = choiceID
        haptic(.light)
        if isHost {
            accept(request, playerID: localID, receivedAt: max(now, clock()))
        } else if let hostPeer {
            if !nearby.send(.guess(request), to: [hostPeer]) { selectedChoice = nil }
        }
    }

    func nextRound() {
        guard isHost, let match, match.stage == .reveal, let round = match.round else { return }
        if round.number < match.roundCount { beginRound(number: round.number + 1) }
        else {
            self.match?.stage = .finished
            screen = .results
            recordStats()
            broadcast()
        }
    }

    func playAgain() {
        guard isHost, let previous = match, previous.stage == .finished else { return }
        var lobby = MatchSnapshot(matchID: UUID(), hostID: localID,
            players: previous.players.filter(\.isConnected).map {
                Player(id: $0.id, name: $0.name, avatar: $0.avatar)
            })
        lobby.collection = settings.collection
        lobby.roundCount = availableRounds
        match = lobby
        selectedChoice = nil
        roundAnswers = [:]
        screen = .lobby
        if isParty {
            // Existing encrypted sessions stay connected; new parties can be hosted from Home.
            broadcast()
        } else { startMatch() }
    }

    func leave() {
        if isParty {
            if isHost { nearby.send(.ended("The host closed the party.")) }
            else if let hostPeer { nearby.send(.leave, to: [hostPeer]) }
        }
        joinTimeout?.cancel()
        nearby.reset()
        peerPlayers = [:]
        hostPeer = nil
        match = nil
        deck = []
        roundAnswers = [:]
        selectedChoice = nil
        clockOffset = 0
        bestRoundTrip = .infinity
        clockProbeCount = 0
        isJoining = false
        soloPaused = false
        pauseStartedAt = nil
        isParty = false
        screen = .home
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func setActive(_ active: Bool) {
        sceneActive = active
        guard screen == .game else { return }
        if isParty {
            // iOS can suspend nearby connections in the background. End explicitly instead
            // of leaving peers waiting indefinitely or awarding an unfair timed advantage.
            if !active {
                leave()
                alert = "The party ended because this app left the foreground. Keep every player’s app open while playing."
            }
        } else if active { resumeSolo() }
        else { pauseSolo() }
    }

    func pauseSolo() {
        guard !isParty, !soloPaused, match?.stage == .round else { return }
        pauseStartedAt = clock()
        soloPaused = true
    }

    func resumeSolo() {
        guard soloPaused, let pausedAt = pauseStartedAt, let round = match?.round else { return }
        let shift = clock().timeIntervalSince(pausedAt)
        match?.round = RoundPrompt(id: round.id, number: round.number, locationID: round.locationID,
            choiceIDs: round.choiceIDs, startsAt: round.startsAt.addingTimeInterval(shift), duration: round.duration)
        soloPaused = false
        pauseStartedAt = nil
        now = clock()
    }

    func tick(_ date: Date) {
        guard screen == .game, !soloPaused else { return }
        now = date.addingTimeInterval(isHost ? 0 : clockOffset)
        guard isHost, match?.stage == .round, let round = match?.round else { return }
        if now >= round.deadline { reveal() }
    }

    private func validateCatalog() -> Bool {
        if let error = catalog.error { alert = error; return false }
        guard catalog.locations.count >= 4,
              catalog.locations.allSatisfy({ LocationCatalog.mediaURL($0.id, extension: "mp4") != nil }) else {
            alert = "The offline video pack is missing. Please reinstall the complete app."
            return false
        }
        return true
    }

    private func makeLobby() -> MatchSnapshot {
        saveSettings()
        var lobby = MatchSnapshot(matchID: UUID(), hostID: localID,
            players: [Player(id: localID, name: settings.name, avatar: settings.avatar)])
        lobby.collection = settings.collection
        lobby.roundCount = availableRounds
        return lobby
    }

    private func beginRound(number: Int) {
        guard let location = deck[safe: number - 1] else { return }
        let lead: TimeInterval = Self.isUITesting ? 0 : 3
        now = clock()
        selectedChoice = nil
        roundAnswers = [:]
        match?.answers = []
        match?.answeredPlayerIDs = []
        match?.round = GameRules.makeRound(location: location, allLocations: catalog.locations,
            number: number, startsAt: now.addingTimeInterval(lead), duration: settings.duration)
        match?.stage = .round
        screen = .game
        UIApplication.shared.isIdleTimerDisabled = true
        broadcast()
    }

    private func accept(_ guess: GuessRequest, playerID: UUID, receivedAt date: Date) {
        guard let match, let round = match.round,
              GameRules.accepts(guess, from: playerID, in: match,
                alreadyAnswered: Set(roundAnswers.keys), now: date) else { return }
        let elapsed = date.timeIntervalSince(round.startsAt)
        roundAnswers[playerID] = Answer(playerID: playerID, roundID: round.id,
            choiceID: guess.choiceID, elapsed: elapsed,
            points: GameRules.points(correct: guess.choiceID == round.locationID, elapsed: elapsed, duration: round.duration))
        self.match?.answeredPlayerIDs = Array(roundAnswers.keys)
        if match.players.filter(\.isConnected).allSatisfy({ roundAnswers[$0.id] != nil }) { reveal() }
        else { broadcast() }
    }

    private func reveal() {
        guard isHost, var match, match.stage == .round, let round = match.round else { return }
        match.stage = .reveal
        match.answers = Array(roundAnswers.values)
        for index in match.players.indices {
            guard let answer = roundAnswers[match.players[index].id] else { continue }
            match.players[index].score += answer.points
            if answer.choiceID == round.locationID {
                match.players[index].correctAnswers += 1
                match.players[index].totalResponseTime += answer.elapsed
            }
        }
        self.match = match
        haptic(.medium)
        broadcast()
    }

    private func broadcast() {
        guard isHost, var match else { return }
        match.revision += 1
        self.match = match
        if isParty { nearby.send(.snapshot(match), to: Array(peerPlayers.keys)) }
    }

    private func connection(_ peer: MCPeerID, connected: Bool) {
        if connected {
            if !isHost, peer == hostPeer {
                nearby.send(.join(JoinRequest(player: Player(id: localID,
                    name: settings.name, avatar: settings.avatar), catalogVersion: GameRules.catalogVersion)), to: [peer])
                sendClockProbe()
            }
        } else if isHost {
            removePeer(peer)
        } else if peer == hostPeer {
            leave()
            alert = "Connection to the host was lost. You can join a new party or play solo."
        }
    }

    private func removePeer(_ peer: MCPeerID) {
        guard let id = peerPlayers.removeValue(forKey: peer), var match else { return }
        if match.stage == .lobby { match.players.removeAll { $0.id == id } }
        else if let index = match.players.firstIndex(where: { $0.id == id }) { match.players[index].isConnected = false }
        self.match = match
        if match.stage == .round,
           match.players.filter(\.isConnected).allSatisfy({ roundAnswers[$0.id] != nil }) { reveal() }
        else { broadcast() }
    }

    private func receive(_ message: WireMessage, from peer: MCPeerID) {
        if isHost {
            switch message {
            case .join(let request):
                guard var match, match.stage == .lobby,
                      match.players.count < GameRules.maximumPlayers,
                      request.catalogVersion == GameRules.catalogVersion,
                      !match.players.contains(where: { $0.id == request.player.id }), peerPlayers[peer] == nil else {
                    nearby.send(.ended("This party is full, already playing, or uses a different location pack."), to: [peer])
                    return
                }
                peerPlayers[peer] = request.player.id
                match.players.append(Player(id: request.player.id,
                    name: GameRules.displayName(request.player.name), avatar: min(7, max(0, request.player.avatar))))
                self.match = match
                broadcast()
            case .guess(let guess):
                guard let id = peerPlayers[peer] else { return }
                // Host arrival time is authoritative; clients cannot claim faster answers.
                accept(guess, playerID: id, receivedAt: clock())
            case .probe(let probe):
                guard peerPlayers[peer] != nil else { return }
                nearby.send(.clock(ClockReply(id: probe.id, sentAt: probe.sentAt, hostTime: clock())), to: [peer])
            case .leave: removePeer(peer)
            default: break
            }
        } else {
            guard peer == hostPeer else { return }
            switch message {
            case .snapshot(let incoming):
                guard incoming.players.contains(where: { $0.id == localID }) else { return }
                if let current = match, current.matchID == incoming.matchID,
                   incoming.revision <= current.revision { return }
                let newRound = match?.round?.id != incoming.round?.id
                let newMatch = match?.matchID != incoming.matchID
                match = incoming
                isJoining = false
                joinTimeout?.cancel()
                if newRound || newMatch { selectedChoice = nil }
                switch incoming.stage {
                case .lobby: screen = .lobby
                case .round, .reveal: screen = .game
                case .finished: screen = .results; recordStats()
                }
                UIApplication.shared.isIdleTimerDisabled = screen == .game
                if incoming.stage == .reveal { haptic(.medium) }
            case .clock(let reply):
                let received = clock()
                let rtt = received.timeIntervalSince(reply.sentAt)
                if rtt >= 0 && rtt < bestRoundTrip {
                    bestRoundTrip = rtt
                    clockOffset = reply.hostTime.timeIntervalSince(reply.sentAt.addingTimeInterval(rtt / 2))
                    now = received.addingTimeInterval(clockOffset)
                }
                // A few probes reduce the effect of one delayed packet on the countdown.
                if rtt.isFinite && bestRoundTrip > 0.005 {
                    clockProbeCount += 1
                    if clockProbeCount < 5 { sendClockProbe() }
                }
            case .ended(let reason): leave(); alert = reason
            default: break
            }
        }
    }

    private var clockProbeCount = 0
    private static var isUITesting: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--uitesting")
        #else
        return false
        #endif
    }

    private func sendClockProbe() {
        guard let hostPeer else { return }
        nearby.send(.probe(ClockProbe(id: UUID(), sentAt: clock())), to: [hostPeer])
    }

    private func recordStats() {
        guard let match, !completedMatches.contains(match.matchID), let player = localPlayer else { return }
        completedMatches.insert(match.matchID)
        stats.bestScore = max(stats.bestScore, player.score)
        stats.gamesPlayed += 1
        stats.locationsGuessed += player.correctAnswers
        if let data = try? JSONEncoder().encode(stats) { defaults.set(data, forKey: "stats") }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        if settings.haptics && sceneActive { UIImpactFeedbackGenerator(style: style).impactOccurred() }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
