import Foundation

/// A stable per-install identity. The UUID is generated once and persisted so
/// a player keeps the same `PlayerInfo.id` across reconnects and rounds.
enum DeviceIdentity {
    private static let idKey = "imposter.playerID"
    private static let nameKey = "imposter.displayName"

    static var playerID: String {
        if let existing = UserDefaults.standard.string(forKey: idKey) {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: idKey)
        return fresh
    }

    static var displayName: String {
        get {
            if let saved = UserDefaults.standard.string(forKey: nameKey), !saved.isEmpty {
                return saved
            }
            return defaultDeviceName()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: nameKey)
        }
    }

    private static func defaultDeviceName() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "Player"
        #endif
    }
}

#if canImport(UIKit)
import UIKit
#endif
