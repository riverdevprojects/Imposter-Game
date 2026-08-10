import Foundation
import MultipeerConnectivity

/// A lobby the browser has discovered nearby.
struct DiscoveredLobby: Identifiable, Equatable {
    let peerID: MCPeerID
    let lobbyName: String
    let playerCount: Int
    var id: String { peerID.displayName }
}

protocol MultipeerManagerDelegate: AnyObject {
    func multipeer(_ manager: MultipeerManager, didReceive message: GameMessage, from peer: MCPeerID)
    func multipeer(_ manager: MultipeerManager, peerDidConnect peer: MCPeerID)
    func multipeer(_ manager: MultipeerManager, peerDidDisconnect peer: MCPeerID)
    /// The host peer went away entirely (client side).
    func multipeerHostDidDisconnect(_ manager: MultipeerManager)
}

/// Thin wrapper over MultipeerConnectivity. Knows nothing about game rules —
/// it advertises/browses/connects and shuttles `GameMessage`s. All delegate
/// callbacks are hopped to the main thread before reaching our delegate.
final class MultipeerManager: NSObject, ObservableObject {
    /// Must be 1–15 chars, lowercase letters/numbers/hyphens.
    static let serviceType = "imposter-game"

    let myPeerID: MCPeerID
    private(set) var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var advertisedLobbyName = ""

    weak var delegate: MultipeerManagerDelegate?

    /// The peer we invited / connected to as a client, so we can tell "the host
    /// left" apart from "a fellow player left".
    private var hostPeerID: MCPeerID?

    @Published var connectedPeers: [MCPeerID] = []
    @Published var discoveredLobbies: [DiscoveredLobby] = []

    init(displayName: String) {
        // MCPeerID display names are limited to 63 bytes.
        let trimmed = String(displayName.prefix(63))
        self.myPeerID = MCPeerID(displayName: trimmed.isEmpty ? "Player" : trimmed)
        super.init()
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    // MARK: - Hosting

    func startAdvertising(lobbyName: String, playerCount: Int) {
        advertisedLobbyName = lobbyName
        restartAdvertiser(playerCount: playerCount)
    }

    func updateAdvertising(playerCount: Int) {
        guard advertiser != nil else { return }
        restartAdvertiser(playerCount: playerCount)
    }

    private func restartAdvertiser(playerCount: Int) {
        advertiser?.stopAdvertisingPeer()
        let info = ["lobby": advertisedLobbyName, "players": String(playerCount)]
        let adv = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: info, serviceType: Self.serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
    }

    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }

    // MARK: - Joining

    func startBrowsing() {
        discoveredLobbies = []
        let b = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        b.delegate = self
        b.startBrowsingForPeers()
        browser = b
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    func join(_ lobby: DiscoveredLobby) {
        hostPeerID = lobby.peerID
        browser?.invitePeer(lobby.peerID, to: session, withContext: nil, timeout: 20)
    }

    // MARK: - Messaging

    func send(_ message: GameMessage, to peers: [MCPeerID]? = nil) {
        let targets = peers ?? session.connectedPeers
        guard !targets.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: targets, with: .reliable)
        } catch {
            print("MultipeerManager send error: \(error)")
        }
    }

    // MARK: - Teardown

    func disconnect() {
        stopAdvertising()
        stopBrowsing()
        session.disconnect()
        hostPeerID = nil
        connectedPeers = []
        discoveredLobbies = []
    }

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }
}

// MARK: - MCSessionDelegate

extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        onMain { [weak self] in
            guard let self else { return }
            self.connectedPeers = session.connectedPeers
            switch state {
            case .connected:
                self.delegate?.multipeer(self, peerDidConnect: peerID)
            case .notConnected:
                if peerID == self.hostPeerID {
                    self.delegate?.multipeerHostDidDisconnect(self)
                } else {
                    self.delegate?.multipeer(self, peerDidDisconnect: peerID)
                }
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(GameMessage.self, from: data) else {
            print("MultipeerManager: undecodable message from \(peerID.displayName)")
            return
        }
        onMain { [weak self] in
            guard let self else { return }
            self.delegate?.multipeer(self, didReceive: message, from: peerID)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // v1: auto-accept every join request (GDD open decision #1).
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("MultipeerManager advertise error: \(error)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        onMain { [weak self] in
            guard let self else { return }
            let name = info?["lobby"] ?? peerID.displayName
            let count = Int(info?["players"] ?? "") ?? 0
            let lobby = DiscoveredLobby(peerID: peerID, lobbyName: name, playerCount: count)
            if let idx = self.discoveredLobbies.firstIndex(where: { $0.peerID == peerID }) {
                self.discoveredLobbies[idx] = lobby
            } else {
                self.discoveredLobbies.append(lobby)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        onMain { [weak self] in
            self?.discoveredLobbies.removeAll { $0.peerID == peerID }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("MultipeerManager browse error: \(error)")
    }
}
