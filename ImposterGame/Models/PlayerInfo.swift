import Foundation

/// A single player in the lobby. `id` is a stable UUID generated once per
/// device install (see `DeviceIdentity`) so a player keeps the same identity
/// even if their `MCPeerID` object changes across reconnects.
struct PlayerInfo: Codable, Identifiable, Equatable, Hashable {
    let id: String
    var displayName: String
    var isHost: Bool
    var isConnected: Bool

    init(id: String, displayName: String, isHost: Bool = false, isConnected: Bool = true) {
        self.id = id
        self.displayName = displayName
        self.isHost = isHost
        self.isConnected = isConnected
    }
}
