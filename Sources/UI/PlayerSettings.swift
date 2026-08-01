import Foundation

enum BufferPreset: String, CaseIterable, Identifiable {
    case automatic
    case saving
    case balanced
    case aggressive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "自动"
        case .saving: return "节省"
        case .balanced: return "均衡"
        case .aggressive: return "激进"
        }
    }

    var seconds: Double {
        switch self {
        case .automatic: return 0
        case .saving: return 30
        case .balanced: return 90
        case .aggressive: return 180
        }
    }
}
