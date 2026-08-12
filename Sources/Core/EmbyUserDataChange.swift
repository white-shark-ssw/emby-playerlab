import Foundation

enum EmbyUserDataChange {
    static let notification = Notification.Name("com.embyplayerlab.userDataDidChange")
    static let itemIDKey = "itemID"
    static let reasonKey = "reason"
    static let manualPlayedReason = "manualPlayed"
    static let playbackStoppedReason = "playbackStopped"
}
