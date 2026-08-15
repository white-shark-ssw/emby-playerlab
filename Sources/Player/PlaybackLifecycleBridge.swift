import Foundation

extension PlayerController {
    @discardableResult
    func pausePlayback() -> Bool {
        guard playbackControlIsPlaying else { return false }
        togglePlayPause()
        return true
    }

    @discardableResult
    func resumePlayback() -> Bool {
        guard !playbackControlIsPlaying else { return false }
        togglePlayPause()
        return true
    }
}
