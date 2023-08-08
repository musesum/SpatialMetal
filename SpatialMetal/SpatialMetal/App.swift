// created by warrens
// modified by musesum

import SwiftUI
import ARKit
import CompositorServices

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

@main
struct SpatialMetalApp: App {

    @State var session = ARKitSession()
    @State var worldTracking = WorldTrackingProvider()

    init() {}

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        ImmersiveSpace(id: "ImmersiveSpace") {
            CompositorLayer(configuration: MetalLayerConfiguration()) { layerRenderer in
                SpatialRenderer_InitAndRun(layerRenderer, session, worldTracking)
            }
        }.immersionStyle(selection: .constant(.full), in: .full)
    }
}
