// created by musesum.

import Spatial
import CompositorServices

// round up to multiple of 256 bytes
let uniformEyesSize = (MemoryLayout<UniformEyes>.size + 0xFF) & -0x100

// uniforms for 3 adjacent frames
let tripleBufferCount = 3

// size of 3 uniforms in shared contiguous memory
let tripleUniformSize = uniformEyesSize * tripleBufferCount

/// triple buffered Uniform for either 1 or 2 eyes
class UniformEyeBuf {

    var uniformBuf: MTLBuffer
    var tripleUniformOffset = 0
    var tripleUniformIndex = 0
    var uniformEyes: UnsafeMutablePointer<UniformEyes>
    var infinitelyFar: Bool // infinit distance for stars (same background for both eyes)

    init(_ device: MTLDevice,
         _ label: String,
         infinitelyFar: Bool) {

        self.infinitelyFar = infinitelyFar

        self.uniformBuf = device.makeBuffer(length: tripleUniformSize,
                                            options: [.storageModeShared])!
        self.uniformBuf.label = label

        uniformEyes = UnsafeMutableRawPointer(uniformBuf.contents())
            .bindMemory(to: UniformEyes.self, capacity: 1)
    }

    /// Update projection and rotation
    func updateUniforms(_ drawable: LayerRenderer.Drawable,
                        _ rotationMat: simd_float4x4) {

        let anchor = drawable.deviceAnchor
        updateTripleBufferedUniform()

        let translateMat = translateQuat(x: 0.0, y: 0.0, z: -8.0)
        let modelMatrix = translateMat * rotationMat
        let simdDeviceAnchor = anchor?.originFromAnchorTransform ?? matrix_identity_float4x4

        self.uniformEyes[0].eye.0 = uniformForEyeIndex(0)
        if drawable.views.count > 1 {
            self.uniformEyes[0].eye.1 = uniformForEyeIndex(1)
        }

        func updateTripleBufferedUniform() {

            tripleUniformIndex = (tripleUniformIndex + 1) % tripleBufferCount
            tripleUniformOffset = uniformEyesSize * tripleUniformIndex
            let uniformPtr = uniformBuf.contents() + tripleUniformOffset
            uniformEyes = UnsafeMutableRawPointer(uniformPtr)
                .bindMemory(to: UniformEyes.self, capacity: 1)
        }

        func uniformForEyeIndex(_ index: Int) -> Uniforms {

            let view = drawable.views[index]
            let viewMatrix = (simdDeviceAnchor * view.transform).inverse
            let projection = ProjectiveTransform3D(
                leftTangent   : Double(view.tangents[0]),
                rightTangent  : Double(view.tangents[1]),
                topTangent    : Double(view.tangents[2]),
                bottomTangent : Double(view.tangents[3]),
                nearZ         : Double(drawable.depthRange.y),
                farZ          : Double(drawable.depthRange.x),
                reverseZ      : true)

            var viewMat = viewMatrix * modelMatrix
            if infinitelyFar {
                viewMat.columns.3 = simd_make_float4(0.0, 0.0, 0.0, 1.0)
            }
            return Uniforms(projectionMat: .init(projection),
                            viewMat: viewMat)
        }
    }
    func setMappings(_ drawable: LayerRenderer.Drawable,
                     _ viewports: [MTLViewport],
                     _ renderCommand: MTLRenderCommandEncoder) {

        if drawable.views.count > 1 {
            var viewMappings = (0 ..< drawable.views.count).map {
                MTLVertexAmplificationViewMapping(
                    viewportArrayIndexOffset: UInt32($0),
                    renderTargetArrayIndexOffset: UInt32($0))
            }
            renderCommand.setVertexAmplificationCount(
                viewports.count,
                viewMappings: &viewMappings)
        }
        renderCommand.setVertexBuffer(uniformBuf,
                                      offset: tripleUniformOffset,
                                      index: Bufi.uniformEyei)
    }
}
