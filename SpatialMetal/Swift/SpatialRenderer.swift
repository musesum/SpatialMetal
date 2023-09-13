//
//  SpatialTest.swift
//  FullyImmersiveMetal
//
//  Created by musesum on 8/4/23.

import Foundation

import simd

struct PoseConstants {
    var projectionMatrix: simd_float4x4
    var viewMatrix: simd_float4x4
}

struct InstanceConstants {
    var modelMatrix: simd_float4x4
}

struct EnvironmentConstants {
    var modelMatrix: simd_float4x4
    var environmentRotation: simd_float4x4
}

// Convert double matrix to float matrix
func matrix_float4x4_from_double4x4(_ m: simd_double4x4) -> simd_float4x4 {
    return simd_float4x4(
        simd_float4(Float(m.columns.0.x), Float(m.columns.0.y), Float(m.columns.0.z), Float(m.columns.0.w)),
        simd_float4(Float(m.columns.1.x), Float(m.columns.1.y), Float(m.columns.1.z), Float(m.columns.1.w)),
        simd_float4(Float(m.columns.2.x), Float(m.columns.2.y), Float(m.columns.2.z), Float(m.columns.2.w)),
        simd_float4(Float(m.columns.3.x), Float(m.columns.3.y), Float(m.columns.3.z), Float(m.columns.3.w))
    )
}

import Foundation
import Metal
import MetalKit
import ARKit
import Spatial
import CompositorServices

import Metal

class SpatialRenderer {
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    var layerRenderer: LayerRenderer

    var environmentRenderPipelineState: MTLRenderPipelineState?
    var contentRenderPipelineState: MTLRenderPipelineState?
    var contentDepthStencilState: MTLDepthStencilState?
    var backgroundDepthStencilState: MTLDepthStencilState?

    var globeMesh: TexturedMesh?
    var environmentMesh: SpatialEnvironmentMesh?
    var sceneTime =  CFTimeInterval(0)
    var lastRenderTime =  CFTimeInterval(0)

    init(layerRenderer: LayerRenderer) {
        self.layerRenderer = layerRenderer
        self.lastRenderTime = CACurrentMediaTime()

        self.device = MTLCreateSystemDefaultDevice()!
        self.commandQueue = device.makeCommandQueue()!

        makeResources()

        makeRenderPipelines(layout: layerRenderer.configuration.layout)
    }

    func makeResources() {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let sphereMesh = MDLMesh.newEllipsoid(withRadii: SIMD3<Float>(0.5, 0.5, 0.5),
                                              radialSegments: 24,
                                              verticalSegments: 24,
                                              geometryType: .triangles,
                                              inwardNormals: false,
                                              hemisphere: false,
                                              allocator: bufferAllocator)
        try! globeMesh = TexturedMesh(mdlMesh: sphereMesh, imageName: "bluemarble.png", device: device)
        try! environmentMesh = SpatialEnvironmentMesh(imageName: "studio.hdr", radius: 3.0, device: device)
    }
    func makeRenderPipelines(layout: LayerRenderer.Layout) {

        var error: NSError?
        let layerConfiguration = layerRenderer.configuration
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = layerConfiguration.colorFormat
        pipelineDescriptor.depthAttachmentPixelFormat = layerConfiguration.depthFormat

        guard let library = device.makeDefaultLibrary() else { return err("library == nil")}
        guard let globeMesh else { return err("globeMesh")}
        guard let environmentMesh else { return err("environmentMesh")}

        var vertexFunction: MTLFunction?
        var fragmentFunction: MTLFunction?

        do {
            vertexFunction = library.makeFunction(name: "vertex_main")
            fragmentFunction = library.makeFunction(name: "fragment_main")
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.vertexDescriptor = globeMesh.vertexDescriptor()
            contentRenderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let pipelineError {
            error = pipelineError as NSError
            err("_main \(error.debugDescription)")
        }

        do {
            vertexFunction = library.makeFunction(name: "vertex_environment")
            fragmentFunction = library.makeFunction(name: "fragment_environment")
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.vertexDescriptor = environmentMesh.vertexDescriptor()
            environmentRenderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let pipelineError {
            error = pipelineError as NSError
            err("_environment \(error.debugDescription)")
        }

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.isDepthWriteEnabled = true
        depthDescriptor.depthCompareFunction = .less
        contentDepthStencilState = device.makeDepthStencilState(descriptor: depthDescriptor)

        depthDescriptor.isDepthWriteEnabled = false
        depthDescriptor.depthCompareFunction = .less
        backgroundDepthStencilState = device.makeDepthStencilState(descriptor: depthDescriptor)
        func err(_ msg: String) {
            print("⁉️ SpatialRenderer::makeRenderPipelines error : \(error.debugDescription)")
        }
    }

    func drawAndPresent(frame: LayerRenderer.Frame, drawable: LayerRenderer.Drawable) {
        guard let globeMesh else { return err("globeMesh") }
        guard let backgroundDepthStencilState else { return err("backgroundDepthStencilState") }
        guard let environmentRenderPipelineState else { return err("environmentRenderPipelineState") }
        guard let environmentMesh else { return err("environmentMesh") }
        guard let contentDepthStencilState else { return err("contentDepthStencilState") }
        guard let contentRenderPipelineState else { return err("contentRenderPipelineState") }

        let renderTime = CACurrentMediaTime()
        let timestep = min(renderTime - lastRenderTime, 1.0 / 60.0)
        sceneTime += timestep

        let c = Float(cos(sceneTime * 0.5))
        let s = Float(sin(sceneTime * 0.5))
        let modelTransform = float4x4([
            SIMD4<Float>(c, 0,  -s, 0),
            SIMD4<Float>(0, 1, 0.0, 0),
            SIMD4<Float>(s, 0,   c, 0),
            SIMD4<Float>(0, 0,-1.5, 1)
        ])
        globeMesh.modelMatrix = modelTransform
        environmentMesh.modelMatrix = modelTransform


        let commandBuffer = commandQueue.makeCommandBuffer()!

        for i in 0 ..< drawable.views.count {
            let rp = createRenderPassDescriptor(drawable: drawable, index: i)
            let ce = commandBuffer.makeRenderCommandEncoder(descriptor: rp)!

            ce.setCullMode(.back)

            var poseConstants = poseConstantsForViewIndex(drawable: drawable, index: i)

            ce.setFrontFacing(.clockwise)
            ce.setDepthStencilState(backgroundDepthStencilState)
            ce.setRenderPipelineState(environmentRenderPipelineState)
            environmentMesh.draw(renderCommandEncoder: ce, poseConstants: &poseConstants)

            ce.setFrontFacing(.counterClockwise)
            ce.setDepthStencilState(contentDepthStencilState)
            ce.setRenderPipelineState(contentRenderPipelineState)
            globeMesh.draw(renderCommandEncoder: ce, poseConstants: &poseConstants)

            ce.endEncoding()
        }
        drawable.encodePresent(commandBuffer: commandBuffer)

        commandBuffer.commit()

        func err(_ msg: String) {
            print("⁉️ SpatialRenderer::drawAndPresent error : \(msg)")
        }
    }

    func createRenderPassDescriptor(drawable: LayerRenderer.Drawable, index: Int) -> MTLRenderPassDescriptor {
        let pd = MTLRenderPassDescriptor()
        pd.colorAttachments[0].texture = drawable.colorTextures[index]
        pd.colorAttachments[0].storeAction = .store
        pd.depthAttachment.texture = drawable.depthTextures[index]
        pd.depthAttachment.storeAction = .store
        pd.renderTargetArrayLength = drawable.views.count
        pd.rasterizationRateMap = nil //?? drawable.rasterizationRateMaps[index] // runtime fail
        return pd
    }

    func poseConstantsForViewIndex(drawable: LayerRenderer.Drawable, index: Int) -> PoseConstants {
        var outPose = PoseConstants(projectionMatrix: float4x4(), viewMatrix: float4x4())
        guard let deviceAnchor = drawable.deviceAnchor else { err("deviceAnchor == nil"); return outPose}
        let poseTransform = deviceAnchor.originFromAnchorTransform

        let view = drawable.views[index]
        let tangents = view.tangents
        let depthRange = drawable.depthRange

        let projectiveTransform = ProjectiveTransform3D(
            leftTangent: Double(tangents[0]),
            rightTangent: Double(tangents[1]),
            topTangent: Double(tangents[2]),
            bottomTangent: Double(tangents[3]),
            nearZ: Double(depthRange[1]),
            farZ: Double(depthRange[0]),
            reverseZ: true)

        outPose.projectionMatrix = matrix_float4x4_from_double4x4(projectiveTransform.matrix)

        let cameraMatrix = poseTransform * view.transform
        outPose.viewMatrix = simd_inverse(cameraMatrix)
        return outPose
        func err(_ msg: String) {
            print("⁉️ SpatialRenderer::SpatialRenderer error : \(msg)")
        }
    }
}
