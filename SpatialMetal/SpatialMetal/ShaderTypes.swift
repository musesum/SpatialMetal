//  Created by musesum on 9/17/23.

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
