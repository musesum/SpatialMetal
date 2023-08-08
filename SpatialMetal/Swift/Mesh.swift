//  Created by musesum on 8/4/23.

import MetalKit
import Spatial

func createTextureFromImage(imageName: String, device: MTLDevice) throws -> MTLTexture? {
    let textureLoader = MTKTextureLoader(device: device)
    guard let imageURL = Bundle.main.url(forResource: imageName, withExtension: nil) else { return nil }
    
    guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        return nil
    }
    
    return try textureLoader.newTexture(cgImage: image, options: nil)
}

class Mesh {

    var modelMatrix: simd_float4x4?

    func vertexDescriptor() -> MTLVertexDescriptor {
        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float3
        vd.attributes[0].bufferIndex = 0
        vd.attributes[0].offset = 0
        vd.attributes[1].format = .float3
        vd.attributes[1].bufferIndex = 0
        vd.attributes[1].offset = MemoryLayout<Float>.size * 3
        vd.attributes[2].format = .float2
        vd.attributes[2].bufferIndex = 0
        vd.attributes[2].offset = MemoryLayout<Float>.size * 6
        vd.layouts[0].stride = MemoryLayout<Float>.size * 8
        return vd
    }
}

class TexturedMesh: Mesh {
    var texture: MTLTexture?
    var mesh: MTKMesh?


    override init() {}
    init(mdlMesh: MDLMesh, imageName: String, device: MTLDevice) throws {
        super.init()
        
        texture = try createTextureFromImage(imageName: imageName, device: device)
        
        let mv = MDLVertexDescriptor()
        mv.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                              format: .float3,
                                              offset: 0,
                                              bufferIndex: 0)
        mv.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                              format: .float3,
                                              offset: MemoryLayout<Float>.size * 3,
                                              bufferIndex: 0)

        mv.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                              format: .float2,
                                              offset: MemoryLayout<Float>.size * 6,
                                              bufferIndex: 0)
        mv.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8)

        mdlMesh.vertexDescriptor = mv
        mesh = try MTKMesh(mesh: mdlMesh, device: device)
    }
    
    func draw(renderCommandEncoder rce: MTLRenderCommandEncoder, poseConstants poseC: inout PoseConstants) {
        guard let modelMatrix else { return err("modelMatrix == nil") }
        var instanceC = InstanceConstants(modelMatrix: modelMatrix)
        
        guard let submesh = mesh?.submeshes.first,
              let vertexBuffer = mesh?.vertexBuffers.first?.buffer else {
            return
        }
        
        rce.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        rce.setVertexBytes(&poseC, length: MemoryLayout<PoseConstants>.stride, index: 1)
        rce.setVertexBytes(&instanceC, length: MemoryLayout<InstanceConstants>.stride, index: 2)
        rce.setFragmentTexture(texture, index: 0)
        rce.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: 0)

        func err(_ msg: String) {
            print("⁉️ TextureMesh::draw error : \(msg)")
        }
    }
}

class SpatialEnvironmentMesh: TexturedMesh {

    var environmentRotation: matrix_float4x4 = matrix_identity_float4x4

    init(imageName: String, radius: CGFloat, device: MTLDevice) throws {
        super.init()
        //super.init(mdlMesh: <#T##MDLMesh#>, imageName: imageName, device: device)

        texture = try createTextureFromImage(imageName: imageName, device: device)
        
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = MDLMesh.newEllipsoid(
            withRadii: SIMD3<Float>(repeating: Float(radius)),
            radialSegments: 24,
            verticalSegments: 24,
            geometryType: .triangles,
            inwardNormals: true,
            hemisphere: false,
            allocator: bufferAllocator)

        let vd = MDLVertexDescriptor()
        vd.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                              format: .float3,
                                              offset: 0,
                                              bufferIndex: 0)

        vd.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                              format: .float3,
                                              offset: MemoryLayout<Float>.size * 3,
                                              bufferIndex: 0)

        vd.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                              format: .float2,
                                              offset: MemoryLayout<Float>.size * 6,
                                              bufferIndex: 0)
        vd.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8)

        mdlMesh.vertexDescriptor = vd
        
        mesh = try MTKMesh(mesh: mdlMesh, device: device)
    }
    
    override func draw(renderCommandEncoder rce: MTLRenderCommandEncoder,
                       poseConstants poseC: inout PoseConstants) {

        guard let modelMatrix else { return err("modelMatrix == nil") }

        var envC = EnvironmentConstants(modelMatrix: modelMatrix,
                                        environmentRotation: matrix_identity_float4x4)

        
        // Remove the translational part of the view matrix to make the environment stay "infinitely" far away
        poseC.viewMatrix.columns.3 = simd_make_float4(0.0, 0.0, 0.0, 1.0)

        guard let submesh = mesh?.submeshes.first,
              let vertexBuffer = mesh?.vertexBuffers.first else {
            return
        }
        
        rce.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
        rce.setVertexBytes(&poseC, length: MemoryLayout<PoseConstants>.size, index: 1)
        rce.setVertexBytes(&envC, length: MemoryLayout<EnvironmentConstants>.size, index: 2)
        rce.setFragmentTexture(texture, index: 0)
        rce.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
        func err(_ msg: String) {
            print("⁉️ SpatialEnvironmentMesh::draw error : \(msg)")
        }
    }
}
