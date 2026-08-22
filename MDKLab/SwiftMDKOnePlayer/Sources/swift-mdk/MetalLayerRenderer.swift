import Foundation
import Metal
import QuartzCore
#if canImport(mdk)
import mdk
#endif

public final class PlayerMetalLayerRenderer: @unchecked Sendable {
    private final class RenderContext: @unchecked Sendable {
        let layer: CAMetalLayer
        let device: MTLDevice
        private let lock = NSLock()
        private var texture: MTLTexture?
        private var enabled = true

        init(layer: CAMetalLayer, device: MTLDevice) {
            self.layer = layer
            self.device = device
            resize(CGSize(width: 1, height: 1))
        }

        func setEnabled(_ value: Bool) {
            lock.lock()
            enabled = value
            lock.unlock()
        }

        func resize(_ size: CGSize) {
            let width = max(1, Int(size.width.rounded()))
            let height = max(1, Int(size.height.rounded()))
            lock.lock()
            if let texture, texture.width == width, texture.height == height { lock.unlock(); return }
            lock.unlock()
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead]
            descriptor.storageMode = .private
            guard let newTexture = device.makeTexture(descriptor: descriptor) else { return }
            lock.lock()
            texture = newTexture
            lock.unlock()
        }

        func acquireRenderTexture() -> MTLTexture? {
            lock.lock()
            defer { lock.unlock() }
            guard enabled else { return nil }
            return texture
        }

        func presentationResources() -> (MTLTexture, CAMetalDrawable)? {
            lock.lock()
            guard enabled, let texture else { lock.unlock(); return nil }
            lock.unlock()
            guard let drawable = layer.nextDrawable() else { return nil }
            lock.lock()
            let stillEnabled = enabled
            lock.unlock()
            guard stillEnabled else { return nil }
            return (texture, drawable)
        }
    }

    public var onFrameSubmitted: (@Sendable (Double) -> Void)?
    public var onRenderCompleted: (@Sendable (Double) -> Void)?

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let context: RenderContext
    private let renderQueue: DispatchQueue
    private let lock = NSLock()
    private weak var player: Player?
    private var active = false
    private var renderScheduled = false
    private var renderPending = false

    public init?(layer: CAMetalLayer) {
        guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.commandQueue = commandQueue
        self.context = RenderContext(layer: layer, device: device)
        self.renderQueue = DispatchQueue(label: "OnePlayer.MDK.Render.\(UUID().uuidString)", qos: .userInteractive)
        layer.device = device
        layer.pixelFormat = .bgra8Unorm
        layer.framebufferOnly = false
        layer.presentsWithTransaction = false
        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, *) { layer.allowsNextDrawableTimeout = true }
    }

    public func prepareSurfaceSize(_ size: CGSize) { context.resize(size) }

    public func bind(_ player: Player) {
        func currentRenderTarget(_ opaque: UnsafeRawPointer?) -> UnsafeRawPointer? {
            guard let opaque else { return nil }
            let context: RenderContext = bridge(ptr: opaque)
            guard let texture = context.acquireRenderTexture() else { return nil }
            return bridge(obj: texture)
        }

        context.setEnabled(true)
        lock.lock()
        self.player = player
        active = true
        renderScheduled = false
        renderPending = false
        lock.unlock()

        var api = mdkMetalRenderAPI()
        api.type = MDK_RenderAPI_Metal
        api.device = bridge(obj: device)
        api.cmdQueue = bridge(obj: commandQueue)
        api.opaque = bridge(obj: context)
        api.currentRenderTarget = currentRenderTarget
        // Keep api.layer zero-initialized: MDK renders only into currentRenderTarget's offscreen texture.
        player.setRenderAPI(&api, vid: self)
        player.setRenderCallback { [weak self] in self?.requestRender() }
    }

    public func setSurfaceSize(_ size: CGSize, player: Player) {
        context.resize(size)
        player.setVideoSurfaceSize(Int32(size.width.rounded()), Int32(size.height.rounded()), vid: self)
    }

    public func detach() {
        lock.lock()
        active = false
        player = nil
        renderPending = false
        lock.unlock()
        context.setEnabled(false)
    }

    public func invalidateNative(_ player: Player) {
        player.setRenderCallback(nil)
        player.setVideoSurfaceSize(Int32(-1), Int32(-1), vid: self)
    }

    private func requestRender() {
        let player: Player
        lock.lock()
        guard active, let current = self.player else { lock.unlock(); return }
        if renderScheduled {
            renderPending = true
            lock.unlock()
            return
        }
        renderScheduled = true
        player = current
        lock.unlock()
        renderQueue.async { [weak self, player] in self?.render(player) }
    }

    private func render(_ player: Player) {
        let startedAt = CACurrentMediaTime()
        let result = player.renderVideo(vid: self)
        lock.lock()
        let shouldSubmit = active && self.player === player
        lock.unlock()

        if shouldSubmit {
            if let (source, drawable) = context.presentationResources(), let buffer = commandQueue.makeCommandBuffer(), let blit = buffer.makeBlitCommandEncoder() {
                let width = min(source.width, drawable.texture.width)
                let height = min(source.height, drawable.texture.height)
                if width > 0, height > 0 {
                    blit.copy(from: source, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: width, height: height, depth: 1), to: drawable.texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                }
                blit.endEncoding()
                buffer.present(drawable)
                buffer.commit()
            }
            onFrameSubmitted?(result)
            onRenderCompleted?((CACurrentMediaTime() - startedAt) * 1_000)
        }

        var scheduleAgain = false
        lock.lock()
        if active, self.player === player, renderPending {
            renderPending = false
            scheduleAgain = true
        } else {
            renderScheduled = false
            renderPending = false
        }
        lock.unlock()
        if scheduleAgain { renderQueue.async { [weak self, player] in self?.render(player) } }
    }
}
