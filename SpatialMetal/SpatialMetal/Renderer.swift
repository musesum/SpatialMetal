//  Created by musesum on 8/4/23.

import MetalKit
import ARKit
import Spatial
import CompositorServices
import simd

class Renderer {

    var delegate: RendererProtocol?
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let inFlightSemaphore = DispatchSemaphore(value: tripleBufferCount)
    let arSession = ARKitSession()
    let worldTracking = WorldTrackingProvider()
    let layerRenderer: LayerRenderer
    var rotation: Float = 0

    init(_ layerRenderer: LayerRenderer) {

        self.layerRenderer = layerRenderer
        self.device = MTLCreateSystemDefaultDevice()!
        self.commandQueue = device.makeCommandQueue()!
    }
    func setDelegate(_ delegate: RendererProtocol) {
        self.delegate = delegate
        delegate.makeResources()
        delegate.makePipeline(layerRenderer)
    }

    func makeRenderPass(drawable: LayerRenderer.Drawable) -> MTLRenderPassDescriptor {

        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = drawable.colorTextures[0]
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)

        renderPass.depthAttachment.texture = drawable.depthTextures[0]
        renderPass.depthAttachment.loadAction = .clear
        renderPass.depthAttachment.storeAction = .store
        renderPass.depthAttachment.clearDepth = 0.0

        renderPass.rasterizationRateMap = drawable.rasterizationRateMaps.first
        if layerRenderer.configuration.layout == .layered {
            renderPass.renderTargetArrayLength = drawable.views.count
        }
        return renderPass
    }

    func renderFrame() {

        guard let delegate else { return }
        guard let frame = layerRenderer.queryNextFrame() else { return }

        frame.startUpdate()
        // Perform frame independent work
        frame.endUpdate()

        guard let timing = frame.predictTiming() else { return }
        LayerRenderer.Clock().wait(until: timing.optimalInputTime)
        guard let drawable = frame.queryDrawable() else { return }

        // triple buffered commandBuf -- ?? completion moved up for readability
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        guard let commandBuf = commandQueue.makeCommandBuffer() else { fatalError("renderFrame::commandBuf") }
        let semaphore = inFlightSemaphore
        commandBuf.addCompletedHandler { (_ commandBuf)-> Swift.Void in
            semaphore.signal()
        }

        frame.startSubmission()

        let time = LayerRenderer.Clock.Instant.epoch.duration(to: drawable.frameTiming.presentationTime).timeInterval

        drawable.deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: time)

        delegate.updateUniforms(drawable)
        delegate.drawAndPresent(commandBuf, frame, drawable)

        frame.endSubmission()


    }

    func startRenderLoop() {
        Task {
            do {
                try await arSession.run([worldTracking])
            } catch {
                fatalError("Failed to initialize ARSession")
            }

            let renderThread = Thread {
                self.renderLoop()
            }
            renderThread.name = "RenderThread"
            renderThread.start()
        }
    }

    func renderLoop() {
        while true {
            switch layerRenderer.state {
            case .paused:  layerRenderer.waitUntilRunning()
            case .running: autoreleasepool { renderFrame() }
            case .invalidated: break
            @unknown default:  print("⁉️ Renderer::runLoop @unknown default")
            }
        }
    }
}
