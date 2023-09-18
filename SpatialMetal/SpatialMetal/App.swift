// created by warrens
// modified by musesum

import SwiftUI
import ARKit
import CompositorServices

@main
struct SpatialMetalApp: App {

    @State var arSession = ARKitSession()
    @State var worldTracking = WorldTrackingProvider()

    init() {}

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        ImmersiveSpace(id: "ImmersiveSpace") {
            CompositorLayer(configuration: MetalLayerConfiguration()) { layerRenderer in

                RenderThread(layerRenderer, arSession, worldTracking).start()
            }
        }.immersionStyle(selection: .constant(.full), in: .full)
    }
}

struct MetalLayerConfiguration: CompositorLayerConfiguration {
    func makeConfiguration(capabilities: LayerRenderer.Capabilities,
                           configuration: inout LayerRenderer.Configuration)
    {
        let supportsFoveation = capabilities.supportsFoveation
        configuration.layout = .dedicated
        configuration.isFoveationEnabled = supportsFoveation
        configuration.colorFormat = .rgba16Float
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
        self.name = "Render Thread"
    }

    override func main() {
        Task {
            let engine = await RenderEngine(layerRenderer,
                                            arSession,
                                            worldTracking)
            engine.runLoop()
        }
    }

}

