import Foundation
import ARKit
import Metal
import MetalKit
import Spatial
import CompositorServices


class SpatialRenderingEngine {
    static func run(_ layerRenderer: LayerRenderer,
                    _ arSession: ARKitSession,
                    _ worldTracking: WorldTrackingProvider) async {

        let engine = await SpatialRenderingEngine(layerRenderer,
                                                  arSession,
                                                  worldTracking)
        engine.runLoop()
    }

    let layerRenderer: LayerRenderer
    var renderer: SpatialRenderer?
    var arSession: ARKitSession?
    var worldTracking: WorldTrackingProvider
    var running = true

    init(_ layerRenderer: LayerRenderer,
         _ arSession: ARKitSession,
         _ worldTracking: WorldTrackingProvider) async {

        self.layerRenderer = layerRenderer
        self.arSession = arSession
        self.worldTracking = worldTracking
        self.renderer = SpatialRenderer(layerRenderer: layerRenderer)
        await runWorldTrackingARSession()
    }
    deinit {
        arSession?.stop()
    }

    func runLoop() {
        while running {
            switch layerRenderer.state {
            case .paused:  layerRenderer.waitUntilRunning()
            case .running: renderFrame()
            case .invalidated: break //?? running = false
            @unknown default:  print("⁉️ SpatialRenderingEngine::runLoop @unknown default")
            }
        }
    }

    private func runWorldTrackingARSession() async  {
        guard let arSession else { return err("arSession") }

        do {
            try await arSession.run([worldTracking])
        } catch {
            err("arSession.run([worldTracking]) error: \(error.localizedDescription)")
        }
        func err(_ msg: String) {
            print("⁉️ SpatialRenderingEngine::renderFrame err: \(msg) == nil")
        }
    }

    private func createPoseForTiming(timing: LayerRenderer.Frame.Timing) -> Pose? {

        let presentationTime = timing.presentationTime
        let queryTime = presentationTime.toTimeInterval()

        guard let outPose = worldTracking.queryPose(atTimestamp: queryTime) else {
            return err("outPose")
        }
        return outPose

        func err(_ msg: String) -> Pose? {
            print("⁉️ SpatialRenderingEngine::createPoseForTiming err: \(msg) == nil")
            return nil
        }
    }

    func renderFrame() {
        guard let frame = layerRenderer.queryNextFrame() else { return err("frame") }
        guard let drawable = frame.queryDrawable() else { return err("drawable") }
        guard let renderer else { return err("renderer") }
        let actualTiming = drawable.frameTiming

        frame.startUpdate()
        // gather_inputs(engine, timing);
        // update_frame(engine, timing, input_state);
        frame.endUpdate()

        // layerRenderer.wait(...) is in docs for beta 5, but cant find, seems to work without
        // guard let timing = frame.predictTiming() else { return err("timing") }
        // let optimalTime = timing.optimalInputTime
        // layerRenderer.wait(until: optimalTime, tolerance: optimalTime)

        frame.startSubmission()
        guard let pose = createPoseForTiming(timing: actualTiming) else { return err("createPoseForTiming") }
        drawable.pose = pose

        renderer.drawAndPresent(frame: frame, drawable: drawable)
        frame.endSubmission()
    }
    func err(_ msg: String) {
        print("⁉️ SpatialRenderingEngine::renderFrame err: \(msg) == nil")
    }
}

class RenderThread: Thread {

    let layerRenderer: LayerRenderer
    let arSession: ARKitSession
    let worldTracking: WorldTrackingProvider

    init(_ layerRenderer: LayerRenderer,
         _ arSession: ARKitSession,
         _ worldTracking: WorldTrackingProvider) {

        self.layerRenderer = layerRenderer
        self.arSession = arSession
        self.worldTracking = worldTracking
        super.init()
    }

    override func main() {
        Task {
            await SpatialRenderingEngine.run(layerRenderer, arSession, worldTracking)
        }
    }
}

public func SpatialRenderer_InitAndRun(_ layerRenderer: LayerRenderer,
                                       _ arSession: ARKitSession,
                                       _ worldTracking: WorldTrackingProvider) {
    let renderThread = RenderThread(layerRenderer, arSession, worldTracking)
    renderThread.name = "Spatial Renderer Thread"
    renderThread.start()
}
