import Foundation

extension MediaStream {
    var displayAspectRatio: Double? {
        let rawRatio: Double?
        if let aspectRatio {
            let normalized = aspectRatio.replacingOccurrences(of: "/", with: ":")
            let parts = normalized.split(separator: ":")
            if parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]), width > 0, height > 0 {
                rawRatio = width / height
            } else {
                rawRatio = nil
            }
        } else if let width, let height, width > 0, height > 0 {
            rawRatio = Double(width) / Double(height)
        } else {
            rawRatio = nil
        }

        guard let rawRatio else { return nil }
        let normalizedRotation = ((rotation ?? 0) % 360 + 360) % 360
        return normalizedRotation == 90 || normalizedRotation == 270 ? 1 / rawRatio : rawRatio
    }
}
