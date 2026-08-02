import Foundation
import KSPlayer

final class KSAVIOOptions: KSOptions {
    private let avioContext: AbstractAVIOContext

    init(context: AbstractAVIOContext) {
        avioContext = context
        super.init()
        preferredForwardBufferDuration = 2
        maxBufferDuration = 30
        isSecondOpen = true
        isAccurateSeek = false
        isSeekedAutoPlay = true
        hardwareDecode = true
        registerRemoteControll = false
    }

    override func process(url: URL) -> AbstractAVIOContext? { avioContext }
}
