import Foundation

/// Host-configurable settings for a round. Broadcast implicitly via the
/// round-start / role-assignment messages; the host is the source of truth.
struct LobbySettings: Codable, Equatable {
    /// Category name, or the sentinel `LobbySettings.randomCategory` to draw
    /// from every category.
    var category: String
    /// Requested number of imposters (1 or 2). Only honored for large enough
    /// lobbies — see `effectiveImposterCount(playerCount:)`.
    var imposterCount: Int
    /// Give the imposter a related decoy word instead of no word at all.
    var useDecoyWord: Bool
    /// Length of the in-person discussion phase, in seconds.
    var discussionSeconds: Int

    static let randomCategory = "Random"

    static let `default` = LobbySettings(
        category: randomCategory,
        imposterCount: 1,
        useDecoyWord: false,        // Option A (Blind Imposter) is the v1 default
        discussionSeconds: 75
    )

    /// The number of imposters actually used, clamped so there is always at
    /// least one regular player. Two imposters are only allowed once there are
    /// at least 7 players (per GDD 4.2).
    func effectiveImposterCount(playerCount: Int) -> Int {
        let requested = (imposterCount == 2 && playerCount >= 7) ? 2 : 1
        return max(1, min(requested, playerCount - 1))
    }
}
