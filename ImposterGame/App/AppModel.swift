import Foundation
import Combine
import MultipeerConnectivity

enum AppScreen: Equatable {
    case mainMenu
    case hostLobby
    case gameSettings
    case joinBrowse
    case waitingRoom
    case roundActive
    case voting
    case roundResult
    case hostDisconnected
}

/// The single coordinator wiring MultipeerConnectivity, the game engine, and
/// SwiftUI navigation together. Views observe it via `@EnvironmentObject`.
///
/// All `@Published` mutations happen on the main thread: the MultipeerManager
/// hops every delegate callback to main before it reaches us.
final class AppModel: ObservableObject, MultipeerManagerDelegate {

    // MARK: Navigation & identity
    @Published var screen: AppScreen = .mainMenu
    @Published var displayName: String = DeviceIdentity.displayName
    let myID = DeviceIdentity.playerID
    @Published var isHost = false

    // MARK: Lobby
    @Published var lobbyName = ""
    @Published var players: [PlayerInfo] = []
    @Published var settings = LobbySettings.default
    @Published var discoveredLobbies: [DiscoveredLobby] = []

    // MARK: Round (this device's view of it)
    @Published var phase: RoundPhase = .lobby
    @Published var myRoleIsImposter = false
    @Published var myWord: String? = nil
    @Published var currentCategory = ""
    @Published var discussionRemaining = 0
    @Published var ballot: [PlayerInfo] = []
    @Published var myVote: String? = nil
    @Published var votesReceived = 0
    @Published var votesExpected = 0
    @Published var result: RoundResultData? = nil

    // MARK: Errors
    @Published var banner: String? = nil

    private(set) var multipeer: MultipeerManager!
    private var engine: GameEngine?
    private var wordBank = WordBank()
    private var discussionTimer: Timer?

    /// Host only: maps a connected peer to the stable player id it announced.
    private var peerToPlayerID: [MCPeerID: String] = [:]

    private var myPlayer: PlayerInfo {
        PlayerInfo(id: myID, displayName: displayName, isHost: isHost, isConnected: true)
    }

    var wordBankCategoryNames: [String] { wordBank.categoryNames }

    // MARK: - Session lifecycle

    private func makeMultipeer() {
        DeviceIdentity.displayName = displayName
        let manager = MultipeerManager(displayName: displayName)
        manager.delegate = self
        // Mirror discovered lobbies into our own @Published copy. `assign(to:)`
        // (vs `assign(to:on:)`) avoids the self-retain cycle.
        manager.$discoveredLobbies
            .receive(on: RunLoop.main)
            .assign(to: &$discoveredLobbies)
        multipeer = manager
    }

    func hostGame() {
        isHost = true
        makeMultipeer()
        engine = GameEngine(wordBank: wordBank)
        lobbyName = "\(displayName)'s Lobby"
        players = [myPlayer]
        multipeer.startAdvertising(lobbyName: lobbyName, playerCount: players.count)
        screen = .hostLobby
    }

    func joinGame() {
        isHost = false
        makeMultipeer()
        players = []
        multipeer.startBrowsing()
        screen = .joinBrowse
    }

    func requestJoin(_ lobby: DiscoveredLobby) {
        lobbyName = lobby.lobbyName
        multipeer.join(lobby)
        screen = .waitingRoom
    }

    func leaveToMainMenu() {
        stopDiscussionTimer()
        multipeer?.disconnect()
        multipeer = nil
        engine = nil
        peerToPlayerID = [:]
        players = []
        discoveredLobbies = []
        result = nil
        myVote = nil
        phase = .lobby
        isHost = false
        screen = .mainMenu
    }

    // MARK: - Host: round control

    func startRound() {
        guard isHost, let engine else { return }
        guard players.filter({ $0.isConnected }).count >= 3 else {
            banner = "Need at least 3 connected players to start."
            return
        }
        let state = engine.startRound(players: players, settings: settings)

        // Tell everyone to move into discussion.
        multipeer.send(.roundStart(category: state.category, discussionSeconds: settings.discussionSeconds))

        // Private per-player role assignment.
        for (peer, pid) in peerToPlayerID {
            let isImp = state.imposterIDs.contains(pid)
            multipeer.send(.roleAssignment(isImposter: isImp, word: state.word(forPlayerID: pid)), to: [peer])
        }

        // Apply the host's own role locally.
        applyRole(isImposter: state.imposterIDs.contains(myID), word: state.word(forPlayerID: myID))
        currentCategory = state.category
        enterDiscussion(seconds: settings.discussionSeconds)
    }

    func hostBeginVoting() {
        guard isHost, let engine else { return }
        engine.beginVoting()
        votesExpected = engine.expectedVoterCount
        votesReceived = 0
        let ballotPlayers = players.filter { $0.isConnected }
        multipeer.send(.startVoting(players: ballotPlayers))
        enterVoting(ballot: ballotPlayers)
    }

    func hostEndVoting() {
        finishVotingIfHost(force: true)
    }

    private func finishVotingIfHost(force: Bool) {
        guard isHost, let engine else { return }
        guard force || engine.allVotesIn else { return }
        engine.endRound()
        guard var result = engine.tally() else { return }
        applyGuessToWinIfNeeded(&result)
        multipeer.send(.roundResult(result: result))
        showResult(result)
    }

    /// Placeholder for the optional "imposter guesses to win" rule. The guess
    /// itself is entered on the imposter's device during the reveal; for v1 the
    /// host simply carries the flag through so the reveal screen can offer it.
    private func applyGuessToWinIfNeeded(_ result: inout RoundResultData) {
        // No automatic steal — handled interactively on the reveal screen.
    }

    func playAgain() {
        guard isHost else { return }
        result = nil
        myVote = nil
        multipeer.send(.playAgainRequest)
        resetToWaiting()
        screen = .hostLobby
    }

    // MARK: - Voting (both sides)

    func castVote(for playerID: String) {
        myVote = playerID
        if isHost {
            guard let engine else { return }
            votesReceived = engine.recordVote(voterID: myID, votedForID: playerID)
            broadcastVoteProgress()
            finishVotingIfHost(force: false)
        } else {
            multipeer.send(.castVote(voterID: myID, votedForID: playerID))
        }
    }

    private func broadcastVoteProgress() {
        guard isHost, let engine else { return }
        multipeer.send(.voteProgress(received: engine.receivedVoteCount, total: engine.expectedVoterCount))
    }

    // MARK: - Local state transitions

    private func applyRole(isImposter: Bool, word: String?) {
        myRoleIsImposter = isImposter
        myWord = word
    }

    private func enterDiscussion(seconds: Int) {
        phase = .discussion
        result = nil
        myVote = nil
        screen = .roundActive
        startDiscussionTimer(seconds: seconds)
    }

    private func enterVoting(ballot: [PlayerInfo]) {
        stopDiscussionTimer()
        phase = .voting
        myVote = nil
        self.ballot = ballot
        screen = .voting
    }

    private func showResult(_ result: RoundResultData) {
        stopDiscussionTimer()
        phase = .results
        self.result = result
        screen = .roundResult
    }

    private func resetToWaiting() {
        stopDiscussionTimer()
        phase = .lobby
        myRoleIsImposter = false
        myWord = nil
        ballot = []
        myVote = nil
        result = nil
    }

    // MARK: - Discussion timer

    private func startDiscussionTimer(seconds: Int) {
        stopDiscussionTimer()
        discussionRemaining = seconds
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            DispatchQueue.main.async {
                if self.discussionRemaining > 0 {
                    self.discussionRemaining -= 1
                } else {
                    t.invalidate()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        discussionTimer = timer
    }

    private func stopDiscussionTimer() {
        discussionTimer?.invalidate()
        discussionTimer = nil
    }

    // MARK: - Host roster management

    private func rebuildAndBroadcastRoster() {
        multipeer.updateAdvertising(playerCount: players.filter { $0.isConnected }.count)
        multipeer.send(.playerListUpdate(players: players))
    }

    // MARK: - MultipeerManagerDelegate

    func multipeer(_ manager: MultipeerManager, didReceive message: GameMessage, from peer: MCPeerID) {
        switch message {
        case .hello(let player):
            guard isHost else { return }
            peerToPlayerID[peer] = player.id
            if let idx = players.firstIndex(where: { $0.id == player.id }) {
                players[idx].isConnected = true
                players[idx].displayName = player.displayName
            } else {
                var p = player
                p.isHost = false
                p.isConnected = true
                players.append(p)
            }
            rebuildAndBroadcastRoster()

        case .playerListUpdate(let list):
            guard !isHost else { return }
            players = list

        case .roundStart(let category, let seconds):
            guard !isHost else { return }
            currentCategory = category
            enterDiscussion(seconds: seconds)

        case .roleAssignment(let isImposter, let word):
            guard !isHost else { return }
            applyRole(isImposter: isImposter, word: word)

        case .startVoting(let ballotPlayers):
            guard !isHost else { return }
            enterVoting(ballot: ballotPlayers)

        case .castVote(let voterID, let votedForID):
            guard isHost, let engine else { return }
            votesReceived = engine.recordVote(voterID: voterID, votedForID: votedForID)
            broadcastVoteProgress()
            finishVotingIfHost(force: false)

        case .voteProgress(let received, let total):
            guard !isHost else { return }
            votesReceived = received
            votesExpected = total

        case .roundResult(let result):
            guard !isHost else { return }
            showResult(result)

        case .playAgainRequest:
            guard !isHost else { return }
            resetToWaiting()
            screen = .waitingRoom

        case .error(let message):
            banner = message
        }
    }

    func multipeer(_ manager: MultipeerManager, peerDidConnect peer: MCPeerID) {
        // Client announces itself so the host can map peer → stable id.
        if !isHost {
            manager.send(.hello(player: myPlayer), to: [peer])
        }
        // Host waits for the hello before adding to the roster.
    }

    func multipeer(_ manager: MultipeerManager, peerDidDisconnect peer: MCPeerID) {
        guard isHost, let pid = peerToPlayerID[peer] else { return }
        peerToPlayerID[peer] = nil
        if phase == .lobby {
            players.removeAll { $0.id == pid }
        } else if let idx = players.firstIndex(where: { $0.id == pid }) {
            players[idx].isConnected = false
        }
        rebuildAndBroadcastRoster()
        // A disconnect may complete voting if the missing player was the holdout.
        if phase == .voting, let engine {
            engine.markDisconnected(playerID: pid)
            votesExpected = engine.expectedVoterCount
            votesReceived = engine.receivedVoteCount
            broadcastVoteProgress()
            finishVotingIfHost(force: false)
        }
    }

    func multipeerHostDidDisconnect(_ manager: MultipeerManager) {
        guard !isHost else { return }
        stopDiscussionTimer()
        screen = .hostDisconnected
    }
}
