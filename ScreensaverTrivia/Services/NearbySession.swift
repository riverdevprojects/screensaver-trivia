import Foundation
import Combine
import MultipeerConnectivity

struct NearbyRoom: Identifiable {
    let peer: MCPeerID
    let name: String
    var id: String { peer.displayName }
}

/// Encrypted, nearby-only transport. The game store owns the authoritative rules.
@MainActor
final class NearbySession: NSObject, ObservableObject {
    @Published private(set) var rooms: [NearbyRoom] = []
    @Published private(set) var status = ""
    var onMessage: ((WireMessage, MCPeerID) -> Void)?
    var onConnection: ((MCPeerID, Bool) -> Void)?
    var onError: ((String) -> Void)?
    var acceptingInvites = true

    private let service = "screen-trivia"
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var hosting = false
    private let networkingEnabled: Bool

    init(networkingEnabled: Bool = true) {
        self.networkingEnabled = networkingEnabled
        super.init()
    }

    func host(name: String) {
        reset()
        hosting = true
        acceptingInvites = true
        status = "Party open · waiting for friends"
        guard networkingEnabled else { return }
        let peer = makeSession()
        advertiser = MCNearbyServiceAdvertiser(peer: peer,
            discoveryInfo: ["name": GameRules.displayName(name), "version": "1"], serviceType: service)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func browse() {
        reset()
        status = "Looking for nearby parties…"
        guard networkingEnabled else { return }
        let peer = makeSession()
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: service)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func join(_ room: NearbyRoom) {
        guard let session else { return }
        status = "Joining \(room.name)’s party…"
        browser?.invitePeer(room.peer, to: session, withContext: nil, timeout: 15)
    }

    func stopAdvertising() { advertiser?.stopAdvertisingPeer() }

    @discardableResult
    func send(_ message: WireMessage, to peers: [MCPeerID]? = nil) -> Bool {
        guard networkingEnabled else { return true }
        guard let session else { return false }
        let recipients = peers ?? session.connectedPeers
        guard !recipients.isEmpty else { return true }
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: recipients, with: .reliable)
            return true
        } catch {
            onError?("The nearby connection was interrupted. Please rejoin the party.")
            return false
        }
    }

    func reset() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        rooms = []
        status = ""
        hosting = false
    }

    private func makeSession() -> MCPeerID {
        let peer = MCPeerID(displayName: UUID().uuidString)
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session
        return peer
    }
}

extension NearbySession: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?,
                                invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            guard self.advertiser === advertiser, self.hosting, self.acceptingInvites,
                  let session = self.session,
                  session.connectedPeers.count < GameRules.maximumPlayers - 1 else {
                invitationHandler(false, nil)
                return
            }
            invitationHandler(true, session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            guard self.advertiser === advertiser else { return }
            self.onError?("Couldn’t open a nearby party. Enable Local Network access in Settings and turn on Wi-Fi and Bluetooth.")
        }
    }
}

extension NearbySession: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        let name = GameRules.displayName(info?["name"] ?? "Explorer")
        guard info?["version"] == "1" else { return }
        Task { @MainActor in
            guard self.browser === browser else { return }
            if !self.rooms.contains(where: { $0.peer == peerID }) {
                self.rooms.append(NearbyRoom(peer: peerID, name: name))
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            guard self.browser === browser else { return }
            self.rooms.removeAll { $0.peer == peerID }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            guard self.browser === browser else { return }
            self.onError?("Couldn’t find nearby parties. Enable Local Network access in Settings and turn on Wi-Fi and Bluetooth.")
        }
    }
}

extension NearbySession: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            guard self.session === session else { return }
            if state == .connected {
                self.status = "Connected · ready to explore"
                self.onConnection?(peerID, true)
            } else if state == .notConnected {
                self.onConnection?(peerID, false)
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard data.count < 128_000,
              let message = try? JSONDecoder().decode(WireMessage.self, from: data) else { return }
        Task { @MainActor in
            guard self.session === session else { return }
            self.onMessage?(message, peerID)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream,
                             withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
