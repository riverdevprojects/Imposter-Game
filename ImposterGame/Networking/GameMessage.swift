import Foundation

/// The single envelope for everything sent between phones. Swift synthesizes
/// `Codable` for enums with associated values, so this JSON-encodes cleanly
/// and travels over `MCSession.send(_:toPeers:with:.reliable)`.
enum GameMessage: Codable {
    /// Client → host, sent immediately on connect so the host learns the
    /// client's stable id and chosen display name. (Not in the original GDD
    /// protocol, but required to map `MCPeerID` ⇄ stable player id.)
    case hello(player: PlayerInfo)

    /// Host → all. The authoritative roster.
    case playerListUpdate(players: [PlayerInfo])

    /// Host → all. Move to the discussion phase. `readyThreshold` is how many
    /// "ready to vote" taps end discussion early (about half the players).
    case roundStart(category: String, discussionSeconds: Int, readyThreshold: Int)

    /// Host → one player. `word` is nil for the imposter unless decoy mode is on.
    case roleAssignment(isImposter: Bool, word: String?)

    /// Client → host. This player wants to end discussion and vote now.
    case readyToVote(voterID: String)

    /// Client → host. This player is taking back their "ready to vote".
    case cancelReadyToVote(voterID: String)

    /// Host → all. Live "X of N ready to vote early" progress.
    case discussionProgress(ready: Int, threshold: Int)

    /// Host → all. Move to the voting phase with the ballot.
    case startVoting(players: [PlayerInfo])

    /// Client → host. A cast vote.
    case castVote(voterID: String, votedForID: String)

    /// Host → all. Live "X of Y votes in" progress.
    case voteProgress(received: Int, total: Int)

    /// Host → all. The reveal. May be sent twice for a caught imposter: first
    /// with `awaitingImposterGuess == true` (word withheld) and again once the
    /// mandatory guess is resolved.
    case roundResult(result: RoundResultData)

    /// Imposter → host. The caught imposter's mandatory guess at the real word.
    case imposterGuess(word: String)

    /// Host → all. Reset back to the waiting room for another round (also used
    /// by the host to cancel/abort a round in progress).
    case playAgainRequest

    /// Either direction. Surface an error to the user.
    case error(message: String)
}

/// Everything the reveal screen needs. Supports one or two imposters.
struct RoundResultData: Codable, Equatable {
    let imposterIDs: [String]
    let imposterNames: [String]
    /// playerID → number of votes received.
    let voteBreakdown: [String: Int]
    /// True if the (single) most-voted player was an imposter.
    let imposterCaught: Bool
    /// The most-voted player when caught — the one who must guess the word.
    var caughtPlayerID: String?
    /// Withheld (empty) while awaiting the mandatory guess; filled on resolve.
    var secretWord: String
    var decoyWord: String?
    /// True while the caught imposter still owes their mandatory guess. The
    /// word is withheld from everyone until this clears.
    var awaitingImposterGuess: Bool = false
    /// True if the caught imposter guessed the word correctly and stole the win.
    var imposterStoleWin: Bool = false
}
