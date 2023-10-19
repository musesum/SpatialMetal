// created by musesum.

import Metal
import CompositorServices

public protocol RendererProtocol {

    func makeResources()

    func makePipeline(_ layoutRenderer: LayerRenderer)

    func updateUniforms(_ drawable: LayerRenderer.Drawable)

    func drawAndPresent(_ commandBuf: MTLCommandBuffer,
                        _ frame: LayerRenderer.Frame,
                        _ drawable: LayerRenderer.Drawable)
}
