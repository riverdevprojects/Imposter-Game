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

    /// Host → all. Move to the discussion phase.
    case roundStart(category: String, discussionSeconds: Int)

    /// Host → one player. `word` is nil for the imposter unless decoy mode is on.
    case roleAssignment(isImposter: Bool, word: String?)

    /// Host → all. Move to the voting phase with the ballot.
    case startVoting(players: [PlayerInfo])

    /// Client → host. A cast vote.
    case castVote(voterID: String, votedForID: String)

    /// Host → all. Live "X of Y votes in" progress.
    case voteProgress(received: Int, total: Int)

    /// Host → all. The reveal.
    case roundResult(result: RoundResultData)

    /// Host → all. Reset back to the waiting room for another round.
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
    let secretWord: String
    let decoyWord: String?
    /// Set only when the "guess to win" rule flips a caught imposter to a win.
    var imposterStoleWin: Bool = false
}
