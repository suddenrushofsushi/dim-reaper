import AppKit
import Metal
import MetalKit
import simd

/// NSView backed by a CAMetalLayer. v1 draws a solid color (black at variable alpha) via a
/// full-screen-triangle fragment shader. The pipeline is intentionally over-built for v1
/// so v2+ effects (blur, gradient, animated noise, color grading) can drop into Shaders.metal
/// without restructuring the view.
final class MetalTintView: NSView, @preconcurrency CALayerDelegate {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let metalLayer = CAMetalLayer()

    private var tintColor: SIMD4<Float> = .init(0, 0, 0, 0.5)
    private var displayLink: CADisplayLink?

    override init(frame frameRect: NSRect) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this Mac.")
        }
        guard let queue = device.makeCommandQueue() else {
            fatalError("Could not create Metal command queue.")
        }
        self.device = device
        self.commandQueue = queue
        self.pipeline = Self.makePipeline(device: device)
        super.init(frame: frameRect)

        wantsLayer = true
        layer = metalLayer
        layerContentsRedrawPolicy = .duringViewResize

        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.isOpaque = false
        metalLayer.contentsScale = window?.backingScaleFactor ?? 2
        metalLayer.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    func setOpacity(_ value: Double) {
        let clamped = Float(max(0, min(1, value)))
        tintColor = SIMD4<Float>(0, 0, 0, clamped)
        needsDisplay = true
    }

    // MARK: - Layout

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let scale = window?.backingScaleFactor {
            metalLayer.contentsScale = scale
        }
        startDisplayLink()
        updateDrawableSize()
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        updateDrawableSize()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateDrawableSize()
    }

    private func updateDrawableSize() {
        let scale = window?.backingScaleFactor ?? metalLayer.contentsScale
        let size = bounds.size
        metalLayer.drawableSize = CGSize(width: size.width * scale, height: size.height * scale)
        needsDisplay = true
    }

    // MARK: - Drawing

    private func startDisplayLink() {
        // For v1 we redraw on demand. A display link is wired up but paused — flip it on once
        // animated shaders land. Left here so the scaffolding for time-varying effects is obvious.
        displayLink?.invalidate()
        displayLink = nil
    }

    func display(_ layer: CALayer) {
        render()
    }

    private func render() {
        guard let drawable = metalLayer.nextDrawable() else { return }
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = drawable.texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0, green: 0, blue: 0, alpha: 0)

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        encoder.setRenderPipelineState(pipeline)
        var color = tintColor
        encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        // Full-screen triangle: 3 verts, generated in the vertex shader from vertex_id.
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Pipeline

    private static func makePipeline(device: MTLDevice) -> MTLRenderPipelineState {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Metal default library not found. Did Shaders.metal compile?")
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "fullscreen_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "tint_fragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Premultiplied alpha blending so the window's transparent background composites correctly
        // against whatever the WindowServer has behind us.
        let attach = descriptor.colorAttachments[0]!
        attach.isBlendingEnabled = true
        attach.rgbBlendOperation = .add
        attach.alphaBlendOperation = .add
        // Fragment outputs premultiplied (rgb already multiplied by alpha), so source factors
        // are .one. Destination uses (1 - srcAlpha) for standard "source over" compositing.
        attach.sourceRGBBlendFactor = .one
        attach.sourceAlphaBlendFactor = .one
        attach.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attach.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to build render pipeline: \(error)")
        }
    }
}
