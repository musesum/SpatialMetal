//
// created by musesum.

import Metal
import MetalKit
import ARKit
import Spatial
import CompositorServices

/// This is the example specific part of rendering metal within VisionOS.
/// The example uses earth in the foreground and stars in the background.
class SpatialRenderer: Renderer {

    var starsPipe: MTLRenderPipelineState?
    var earthPipe: MTLRenderPipelineState?
    var earthMesh: MeshEllipsoid?
    var starsMesh: MeshEllipsoid?
    var starsEyeBuf: UniformEyeBuf?
    var earthEyeBuf: UniformEyeBuf?

    override init(_ layerRenderer: LayerRenderer) {
        super.init(layerRenderer)
        setDelegate(self)
        startRenderLoop()
    }
}

extension SpatialRenderer: RendererProtocol {

    func makeResources() {
        // stars is from 8k_stars_milky_way.jpg via
        // https://www.solarsystemscope.com/textures/ -- CC Atribution 4.0
        starsEyeBuf = UniformEyeBuf(device, "stars", infinitelyFar: true)
        earthEyeBuf = UniformEyeBuf(device, "earth", infinitelyFar: false)
        do {
            try earthMesh = MeshEllipsoid(device, "Earth", .less,    radius: 2.5, inward: false)
            try starsMesh = MeshEllipsoid(device, "Stars", .greater, radius: 3.0, inward: true)
        } catch {
            fatalError("\(#function) Error: \(error)")
        }
    }
    func makePipeline(_ layoutRenderer: LayerRenderer) {
        guard let library = device.makeDefaultLibrary() else { return err("library = nil")}
        guard let earthMesh else { return err("earthMesh")}
        guard let starsMesh else { return err("starsMesh")}
        do {
            let configuration = layerRenderer.configuration
            let pd = MTLRenderPipelineDescriptor()
            pd.colorAttachments[0].pixelFormat = configuration.colorFormat
            pd.depthAttachmentPixelFormat = configuration.depthFormat

            // earth.metal
            pd.vertexFunction   = library.makeFunction(name: "vertexEarth")
            pd.fragmentFunction = library.makeFunction(name: "fragmentEarth")
            pd.vertexDescriptor = earthMesh.metalVD
            earthPipe = try device.makeRenderPipelineState(descriptor: pd)

            // stars.metal
            pd.vertexFunction   = library.makeFunction(name: "vertexStars")
            pd.fragmentFunction = library.makeFunction(name: "fragmentStars")
            pd.vertexDescriptor = starsMesh.metalVD
            starsPipe = try device.makeRenderPipelineState(descriptor: pd)

        } catch let error {
            err("compile \(error.localizedDescription)")
        }

        func err(_ msg: String) {
            print("⁉️ SpatialRenderer::\(#function) error: \(msg)")
        }
    }

    /// Update projection and rotation
    func updateUniforms(_ drawable: LayerRenderer.Drawable) {
        
        let rotationAxis = SIMD3<Float>(0, 1, 0)
        let rotationEarth = rotateQuat(radians: rotation, 
                                       axis: rotationAxis)
        
        let rotationStars =  rotateQuat(radians: 0,
                                        axis: rotationAxis)
        rotation += 0.003

        starsEyeBuf?.updateUniforms(drawable, rotationStars)
        earthEyeBuf?.updateUniforms(drawable, rotationEarth)
    }

    func drawAndPresent(_ commandBuf: MTLCommandBuffer,
                        _ frame: LayerRenderer.Frame,
                        _ drawable: LayerRenderer.Drawable) {

        let renderPass = makeRenderPass(drawable: drawable)
        
        guard let starsMesh, let starsPipe, let starsEyeBuf,
              let earthMesh, let earthPipe, let earthEyeBuf,
              let renderCommand = commandBuf .makeRenderCommandEncoder(
                descriptor: renderPass) else { fatalError(#function) }

        renderCommand.label = "Spatial"
        renderCommand.pushDebugGroup("Spatial")

        let viewports = drawable.views.map { $0.textureMap.viewport }
        renderCommand.setViewports(viewports)

        starsEyeBuf.setMappings(drawable, viewports, renderCommand)
        starsMesh.draw(renderCommand, starsPipe, .clockwise)

        earthEyeBuf.setMappings(drawable, viewports, renderCommand)
        earthMesh.draw(renderCommand, earthPipe, .counterClockwise)

        renderCommand.popDebugGroup()
        renderCommand.endEncoding()
        drawable.encodePresent(commandBuffer: commandBuf)
        commandBuf.commit()
    }

}

