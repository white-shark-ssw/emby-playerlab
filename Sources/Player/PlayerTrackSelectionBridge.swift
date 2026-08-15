import AVFoundation
import Foundation

enum PlayerSelectableTrackKind: String, Hashable {
    case audio
    case subtitle

    var title: String {
        switch self {
        case .audio: return "音轨"
        case .subtitle: return "字幕"
        }
    }

    var characteristic: AVMediaCharacteristic {
        switch self {
        case .audio: return .audible
        case .subtitle: return .legible
        }
    }
}

struct PlayerSelectableTrack: Identifiable, Hashable {
    let kind: PlayerSelectableTrackKind
    let optionIndex: Int?
    let title: String
    let detail: String?
    let isSelected: Bool

    var id: String { "\(kind.rawValue):\(optionIndex.map(String.init) ?? "off")" }
    var isOffOption: Bool { optionIndex == nil }
}

@MainActor
extension PlayerController {
    var supportsInteractiveTrackSelection: Bool { avPlayer?.currentItem != nil }

    func selectableTracks() -> [PlayerSelectableTrack] {
        guard let item = avPlayer?.currentItem else { return [] }
        var result: [PlayerSelectableTrack] = []
        result.append(contentsOf: selectableTracks(kind: .audio, item: item))
        result.append(contentsOf: selectableTracks(kind: .subtitle, item: item))
        return result
    }

    @discardableResult
    func selectTrack(_ track: PlayerSelectableTrack) -> Bool {
        guard let player = avPlayer,
              let item = player.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: track.kind.characteristic) else { return false }

        let option: AVMediaSelectionOption?
        if let optionIndex = track.optionIndex {
            guard group.options.indices.contains(optionIndex) else { return false }
            option = group.options[optionIndex]
        } else {
            guard track.kind == .subtitle, group.allowsEmptySelection else { return false }
            option = nil
        }

        item.select(option, in: group)
        let selected = item.currentMediaSelection.selectedMediaOption(in: group)
        let succeeded: Bool
        if let option { succeeded = selected === option }
        else { succeeded = selected == nil }

        DiagnosticsLogger.shared.playback(
            "PlayerTrack",
            "select kind=\(track.kind.rawValue) option=\(track.optionIndex.map(String.init) ?? "off") title=\(track.title) succeeded=\(succeeded)"
        )
        return succeeded
    }

    private func selectableTracks(kind: PlayerSelectableTrackKind, item: AVPlayerItem) -> [PlayerSelectableTrack] {
        guard let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: kind.characteristic) else { return [] }
        let selected = item.currentMediaSelection.selectedMediaOption(in: group)
        var tracks: [PlayerSelectableTrack] = []

        if kind == .subtitle, group.allowsEmptySelection {
            tracks.append(PlayerSelectableTrack(kind: kind, optionIndex: nil, title: "关闭字幕", detail: nil, isSelected: selected == nil))
        }

        tracks.append(contentsOf: group.options.enumerated().map { index, option in
            PlayerSelectableTrack(
                kind: kind,
                optionIndex: index,
                title: option.displayName,
                detail: trackDetail(option),
                isSelected: selected === option
            )
        })
        return tracks
    }

    private func trackDetail(_ option: AVMediaSelectionOption) -> String? {
        var parts: [String] = []
        if let locale = option.locale {
            let language = locale.localizedString(forLanguageCode: locale.languageCode ?? "") ?? locale.identifier
            if !language.isEmpty, language != option.displayName { parts.append(language) }
        }
        if option.hasMediaCharacteristic(.containsOnlyForcedSubtitles) { parts.append("强制") }
        if option.hasMediaCharacteristic(.describesVideoForAccessibility) { parts.append("音频描述") }
        if option.hasMediaCharacteristic(.transcribesSpokenDialogForAccessibility) { parts.append("辅助字幕") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}