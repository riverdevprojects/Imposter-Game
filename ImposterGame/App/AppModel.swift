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

    // MARK: End-discussion-early votes
    @Published var iAmReady = false
    @Published var readyCount = 0
    @Published var readyThreshold = 0

    // MARK: Errors
    @Published var banner: String? = nil

    private(set) var multipeer: MultipeerManager!
    private var engine: GameEngine?
    private var wordBank = WordBank()
    private var discussionTimer: Timer?

    /// Host only: maps a connected peer to the stable player id it announced.
    private var peerToPlayerID: [MCPeerID: String] = [:]

    /// Host only: players who have tapped "Ready to Vote" this discussion.
    private var readyVoters: Set<String> = []

    /// Host only: the full result (with the real word) held back while the
    /// caught imposter completes their mandatory guess.
    private var pendingFullResult: RoundResultData? = nil

    /// Number of "ready" taps needed to end discussion early — about half the
    /// connected players (majority-rounded).
    private func earlyEndThreshold(for connectedCount: Int) -> Int {
        max(1, (connectedCount + 1) / 2)
    }

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
        readyVoters = []
        let threshold = earlyEndThreshold(for: players.filter { $0.isConnected }.count)

        // Tell everyone to move into discussion.
        multipeer.send(.roundStart(category: state.category,
                                   discussionSeconds: settings.discussionSeconds,
                                   readyThreshold: threshold))

        // Private per-player role assignment.
        for (peer, pid) in peerToPlayerID {
            let isImp = state.imposterIDs.contains(pid)
            multipeer.send(.roleAssignment(isImposter: isImp, word: state.word(forPlayerID: pid)), to: [peer])
        }

        // Apply the host's own role locally.
        applyRole(isImposter: state.imposterIDs.contains(myID), word: state.word(forPlayerID: myID))
        currentCategory = state.category
        readyThreshold = threshold
        enterDiscussion(seconds: settings.discussionSeconds)
    }

    func hostBeginVoting() {
        // Idempotent: the timer expiring and the early-end threshold can race.
        guard isHost, let engine, phase == .discussion else { return }
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
        guard isHost, let engine, phase == .voting else { return }
        guard force || engine.allVotesIn else { return }
        engine.endRound()
        guard let full = engine.tally() else { return }

        if full.imposterCaught {
            // Mandatory guess: reveal that the imposter was caught, but withhold
            // the word from everyone until the caught imposter has guessed.
            pendingFullResult = full
            var awaiting = full
            awaiting.awaitingImposterGuess = true
            awaiting.secretWord = ""
            awaiting.decoyWord = nil
            multipeer.send(.roundResult(result: awaiting))
            showResult(awaiting)
        } else {
            pendingFullResult = nil
            multipeer.send(.roundResult(result: full))
            showResult(full)
        }
    }

    /// Called on the caught imposter's device when they submit their guess.
    func submitImposterGuess(_ word: String) {
        if isHost {
            resolveImposterGuess(word)
        } else {
            multipeer.send(.imposterGuess(word: word))
        }
    }

    /// Host: score the caught imposter's guess and broadcast the final result.
    private func resolveImposterGuess(_ word: String) {
        guard isHost, var full = pendingFullResult else { return }
        let guessed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        full.imposterStoleWin = (guessed == full.secretWord.lowercased())
        full.awaitingImposterGuess = false
        pendingFullResult = nil
        multipeer.send(.roundResult(result: full))
        showResult(full)
    }

    func playAgain() {
        guard isHost else { return }
        broadcastRoundResetAndReturnToLobby()
    }

    /// Host-only escape hatch: abort the round in progress (e.g. a misdeal, or
    /// the caught imposter can't guess) and send everyone back to the lobby.
    func hostCancelRound() {
        guard isHost else { return }
        broadcastRoundResetAndReturnToLobby()
    }

    private func broadcastRoundResetAndReturnToLobby() {
        readyVoters = []
        pendingFullResult = nil
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

    // MARK: - End discussion early

    /// Toggle this player's "Ready to Vote" during discussion — tap to ready,
    /// tap again to take it back.
    func toggleReadyToVote() {
        guard phase == .discussion else { return }
        if iAmReady {
            iAmReady = false
            if isHost { unregisterReady(playerID: myID) }
            else { multipeer.send(.cancelReadyToVote(voterID: myID)) }
        } else {
            iAmReady = true
            if isHost { registerReady(playerID: myID) }
            else { multipeer.send(.readyToVote(voterID: myID)) }
        }
    }

    /// Host: record a ready vote, broadcast progress, and end discussion early
    /// once enough players are ready.
    private func registerReady(playerID: String) {
        guard isHost, phase == .discussion else { return }
        readyVoters.insert(playerID)
        readyCount = readyVoters.count
        multipeer.send(.discussionProgress(ready: readyCount, threshold: readyThreshold))
        if readyCount >= readyThreshold {
            hostBeginVoting()
        }
    }

    /// Host: a player took back their ready vote.
    private func unregisterReady(playerID: String) {
        guard isHost, phase == .discussion else { return }
        readyVoters.remove(playerID)
        readyCount = readyVoters.count
        multipeer.send(.discussionProgress(ready: readyCount, threshold: readyThreshold))
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
        iAmReady = false
        readyCount = 0
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
                }
                if self.discussionRemaining <= 0 {
                    t.invalidate()
                    // Time's up: the host authoritatively moves everyone to voting.
                    if self.isHost { self.hostBeginVoting() }
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

        case .roundStart(let category, let seconds, let threshold):
            guard !isHost else { return }
            currentCategory = category
            readyThreshold = threshold
            enterDiscussion(seconds: seconds)

        case .roleAssignment(let isImposter, let word):
            guard !isHost else { return }
            applyRole(isImposter: isImposter, word: word)

        case .readyToVote(let voterID):
            guard isHost else { return }
            registerReady(playerID: voterID)

        case .cancelReadyToVote(let voterID):
            guard isHost else { return }
            unregisterReady(playerID: voterID)

        case .discussionProgress(let ready, let threshold):
            guard !isHost else { return }
            readyCount = ready
            readyThreshold = threshold

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

        case .imposterGuess(let word):
            guard isHost else { return }
            resolveImposterGuess(word)

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
        // A disconnect changes the "half the players" math for ending discussion
        // early, and may itself push us over the threshold.
        if phase == .discussion {
            readyVoters.remove(pid)
            readyThreshold = earlyEndThreshold(for: players.filter { $0.isConnected }.count)
            readyCount = readyVoters.count
            multipeer.send(.discussionProgress(ready: readyCount, threshold: readyThreshold))
            if readyCount >= readyThreshold { hostBeginVoting() }
        }
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
