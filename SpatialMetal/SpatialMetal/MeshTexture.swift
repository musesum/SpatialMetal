//  Created by musesum on 8/4/23.

import MetalKit
import Spatial

class MeshTexture {

    var texName: String
    var texture: MTLTexture
    var metalVD: MTLVertexDescriptor
    var mesh: MTKMesh?
    var stencil: MTLDepthStencilState?
    var device: MTLDevice

    init(device  : MTLDevice,
         texName : String,
         compare : MTLCompareFunction) throws {

        self.device = device
        self.texName = texName
        texture = loadTexture(device, texName)
        metalVD = MTLVertexDescriptor()

        let sd = MTLDepthStencilDescriptor()
        sd.isDepthWriteEnabled = true
        sd.depthCompareFunction = compare
        stencil = device.makeDepthStencilState(descriptor: sd)
    }

    func draw(_ renderCommand: MTLRenderCommandEncoder,
              _ pipeline: MTLRenderPipelineState,
              _ winding: MTLWinding) {

        guard let stencil else { return err("\(texName) stencil") }
        guard let mesh    else { return err("\(texName) mesh") }

        renderCommand.setCullMode(.back)
        renderCommand.setRenderPipelineState(pipeline)
        renderCommand.setFrontFacing(winding)
        renderCommand.setDepthStencilState(stencil)

        for (index, element) in mesh.vertexDescriptor.layouts.enumerated() {
            guard let layout = element as? MDLVertexBufferLayout else { return }

            if layout.stride != 0 {
                let vb = mesh.vertexBuffers[index]
                renderCommand.setVertexBuffer(vb.buffer, offset: vb.offset, index: index)
            }
        }
        renderCommand.setFragmentTexture(texture, index: Texturei.colori)

        for submesh in mesh.submeshes {
            renderCommand.drawIndexedPrimitives(
                type              : submesh.primitiveType,
                indexCount        : submesh.indexCount,
                indexType         : submesh.indexType,
                indexBuffer       : submesh.indexBuffer.buffer,
                indexBufferOffset : submesh.indexBuffer.offset)
        }
        func err(_ msg: String) {
            print("⁉️ \(texName) Mesh::draw error : \(msg)")
        }
    }
}

class MeshEllipsoid: MeshTexture {

    var radius = CGFloat(1)
    var inward = false

    init(_ device  : MTLDevice,
         _ texName : String,
         _ compare : MTLCompareFunction,
         radius    : CGFloat,
         inward    : Bool) throws {

        try super.init(device  : device,
                       texName : texName,
                       compare : compare)

        self.radius = radius
        self.inward = inward

        guard let modelMesh = modelEllipsoid(device) else {
            throw RendererError.badVertex
        }
        mesh = try MTKMesh(mesh: modelMesh, device: device)

        func err(_ msg: String) {
            print("⁉️ \(texName) Mesh::draw error : \(msg)")
        }
    }

    func modelEllipsoid(_ device: MTLDevice) -> MDLMesh? {

        makeMetalVD()
        let allocator = MTKMeshBufferAllocator(device: device)
        let radii = SIMD3<Float>(repeating: Float(radius))
        let modelMesh = MDLMesh.newEllipsoid(
            withRadii        : radii,
            radialSegments   : 24,
            verticalSegments : 24,
            geometryType     : .triangles,
            inwardNormals    : inward,
            hemisphere       : false,
            allocator        : allocator)

        let modelVD = MTKModelIOVertexDescriptorFromMetal(metalVD)
        guard let attributes = modelVD.attributes as? [MDLVertexAttribute] else {
            return nil
        }
        attributes[Vertexi.position].name = MDLVertexAttributePosition
        attributes[Vertexi.normal  ].name = MDLVertexAttributeNormal
        attributes[Vertexi.texcoord].name = MDLVertexAttributeTextureCoordinate

        modelMesh.vertexDescriptor = modelVD
        return modelMesh
    }
    func makeMetalVD() {

        let vd = MTLVertexDescriptor()
        addVertexFormat(.float3, Vertexi.position, Bufi.positioni)
        addVertexFormat(.float2, Vertexi.normal  , Bufi.normali  )
        addVertexFormat(.float3, Vertexi.texcoord, Bufi.texcoordi)

        func addVertexFormat(_ format: MTLVertexFormat,
                             _ vertexi: Int,
                             _ layouti: Int ) {
            let stride: Int
            switch format {
            case .float2: stride = MemoryLayout<Float>.size * 2
            case .float3: stride = MemoryLayout<Float>.size * 3
            default: return
            }
            vd.attributes[vertexi].format = format
            vd.attributes[vertexi].offset = 0
            vd.attributes[vertexi].bufferIndex = layouti
            vd.layouts[layouti].stride = stride
            vd.layouts[layouti].stepRate = 1
            vd.layouts[layouti].stepFunction = .perVertex
        }
        metalVD = vd
    }
}
