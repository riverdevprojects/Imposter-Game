import Foundation

enum RoundPhase: String, Codable {
    case lobby
    case discussion
    case voting
    case results
}

/// The host-authoritative state for a single round.
struct RoundState {
    var players: [PlayerInfo]
    var imposterIDs: Set<String>
    var secretWord: String
    var decoyWord: String?
    var category: String
    /// voterID → votedForID
    var votes: [String: String] = [:]
    var phase: RoundPhase = .discussion

    /// Players eligible to give clues and vote (connected only).
    var activePlayers: [PlayerInfo] { players.filter { $0.isConnected } }

    /// The word a given player should see: the secret word for regulars,
    /// the decoy (or nil) for imposters.
    func word(forPlayerID id: String) -> String? {
        imposterIDs.contains(id) ? decoyWord : secretWord
    }
}
