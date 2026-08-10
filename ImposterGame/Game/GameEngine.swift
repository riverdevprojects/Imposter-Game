import Foundation

/// Host-side round lifecycle: role assignment, vote tally, results. Runs
/// meaningfully only on the host device. Clients render whatever the host
/// broadcasts.
final class GameEngine {
    let wordBank: WordBank
    private(set) var round: RoundState?

    init(wordBank: WordBank = WordBank()) {
        self.wordBank = wordBank
    }

    /// Begin a new round. Picks imposter(s), the secret word, and (optionally)
    /// a decoy, then returns the fresh `RoundState`.
    @discardableResult
    func startRound(players: [PlayerInfo], settings: LobbySettings) -> RoundState {
        let active = players.filter { $0.isConnected }
        let imposterCount = settings.effectiveImposterCount(playerCount: active.count)
        let imposterIDs = Set(active.shuffled().prefix(imposterCount).map { $0.id })

        let category = settings.category == LobbySettings.randomCategory
            ? wordBank.randomCategoryName()
            : settings.category
        let secret = wordBank.pickWord(category: category)
        let decoy = settings.useDecoyWord ? wordBank.pickDecoy(category: category, excluding: secret) : nil

        let state = RoundState(
            players: players,
            imposterIDs: imposterIDs,
            secretWord: secret,
            decoyWord: decoy,
            category: category,
            votes: [:],
            phase: .discussion
        )
        round = state
        return state
    }

    func beginVoting() {
        round?.phase = .voting
        round?.votes = [:]
    }

    /// Reflect a mid-round disconnect so vote-completion math stays correct: the
    /// player no longer counts as an expected voter, and any vote they hadn't
    /// cast is simply never expected.
    func markDisconnected(playerID: String) {
        guard let idx = round?.players.firstIndex(where: { $0.id == playerID }) else { return }
        round?.players[idx].isConnected = false
        round?.votes[playerID] = nil
    }

    /// Record a vote. Returns the number of votes received so far.
    @discardableResult
    func recordVote(voterID: String, votedForID: String) -> Int {
        round?.votes[voterID] = votedForID
        return round?.votes.count ?? 0
    }

    /// Number of players expected to vote (connected players only).
    var expectedVoterCount: Int { round?.activePlayers.count ?? 0 }
    var receivedVoteCount: Int { round?.votes.count ?? 0 }
    var allVotesIn: Bool { receivedVoteCount >= expectedVoterCount && expectedVoterCount > 0 }

    /// Tally the round and produce the reveal payload.
    func tally() -> RoundResultData? {
        guard let round else { return nil }

        var breakdown: [String: Int] = [:]
        for player in round.players { breakdown[player.id] = 0 }
        for (_, votedFor) in round.votes { breakdown[votedFor, default: 0] += 1 }

        // Most-voted player (strict winner). Ties → nobody is caught.
        let caught: Bool
        let sorted = breakdown.sorted { $0.value > $1.value }
        if let top = sorted.first, top.value > 0 {
            let tie = sorted.dropFirst().first?.value == top.value
            caught = !tie && round.imposterIDs.contains(top.key)
        } else {
            caught = false
        }

        let imposterPlayers = round.players.filter { round.imposterIDs.contains($0.id) }
        return RoundResultData(
            imposterIDs: imposterPlayers.map { $0.id },
            imposterNames: imposterPlayers.map { $0.displayName },
            voteBreakdown: breakdown,
            imposterCaught: caught,
            secretWord: round.secretWord,
            decoyWord: round.decoyWord
        )
    }

    func endRound() {
        round?.phase = .results
    }
}
