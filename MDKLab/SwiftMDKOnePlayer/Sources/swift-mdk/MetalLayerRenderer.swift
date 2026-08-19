import Foundation
import Metal
import QuartzCore
#if canImport(mdk)
import mdk
#endif

public final class PlayerMetalLayerRenderer: @unchecked Sendable {
    private final class RenderContext: @unchecked Sendable {
        let layer: CAMetalLayer
        private let lock = NSLock()
        private var drawable: CAMetalDrawable?
        private var enabled = true

        init(layer: CAMetalLayer) { self.layer = layer }

        func setEnabled(_ value: Bool) {
            lock.lock()
            enabled = value
            if !value { drawable = nil }
            lock.unlock()
        }

        func acquireTexture() -> MTLTexture? {
            lock.lock()
            let allowed = enabled
            lock.unlock()
            guard allowed, let next = layer.nextDrawable() else { return nil }
            lock.lock()
            guard enabled else { lock.unlock(); return nil }
            drawable = next
            lock.unlock()
            return next.texture
        }

        func takeDrawable() -> CAMetalDrawable? {
            lock.lock()
            let value = drawable
            drawable = nil
            lock.unlock()
            return value
        }

        func clearDrawable() {
            lock.lock()
            drawable = nil
            lock.unlock()
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
        self.context = RenderContext(layer: layer)
        self.renderQueue = DispatchQueue(label: "OnePlayer.MDK.Render.\(UUID().uuidString)", qos: .userInteractive)
        layer.device = device
        layer.pixelFormat = .bgra8Unorm
        layer.framebufferOnly = true
        layer.presentsWithTransaction = false
        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, *) { layer.allowsNextDrawableTimeout = true }
    }

    public func bind(_ player: Player) {
        func currentRenderTarget(_ opaque: UnsafeRawPointer?) -> UnsafeRawPointer? {
            guard let opaque else { return nil }
            let context: RenderContext = bridge(ptr: opaque)
            guard let texture = context.acquireTexture() else { return nil }
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
        api.layer = bridge(obj: context.layer)
        player.setRenderAPI(&api, vid: self)
        player.setRenderCallback { [weak self] in self?.requestRender() }
    }

    public func setSurfaceSize(_ size: CGSize, player: Player) {
        player.setVideoSurfaceSize(Int32(size.width.rounded()), Int32(size.height.rounded()), vid: self)
    }

    public func detach() {
        lock.lock()
        active = false
        player = nil
        renderPending = false
        lock.unlock()
        context.setEnabled(false)
        context.clearDrawable()
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
            if let drawable = context.takeDrawable(), let buffer = commandQueue.makeCommandBuffer() {
                buffer.present(drawable)
                buffer.commit()
            }
            onFrameSubmitted?(result)
            onRenderCompleted?((CACurrentMediaTime() - startedAt) * 1_000)
        } else {
            context.clearDrawable()
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
