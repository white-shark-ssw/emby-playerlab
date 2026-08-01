import Foundation
import UIKit

enum AppIdentity {
    static let clientName = "Emby Player Lab"
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    static let deviceName = UIDevice.current.model
    static let ticksPerSecond: Double = 10_000_000

    static var deviceId: String {
        let key = "EmbyPlayerLab.DeviceId"
        if let value = UserDefaults.standard.string(forKey: key), !value.isEmpty {
            return value
        }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
}
