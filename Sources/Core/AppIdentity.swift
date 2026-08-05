import Darwin
import Foundation

enum AppIdentity {
    static let clientName = "Emby Player Lab"
    static let sourceVersion = "0.7.2"
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.7.2"
    static let ticksPerSecond: Double = 10_000_000

    static var deviceName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = Mirror(reflecting: systemInfo.machine).children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
        return machine.isEmpty ? "iOS Device" : machine
    }

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
