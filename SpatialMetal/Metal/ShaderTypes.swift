//  Created by musesum on 9/17/23.

import simd

struct Bufi  {
    static let positioni   = 0
    static let texcoordi   = 1
    static let normali     = 2
    static let uniformEyei = 3
}

struct Vertexi {
    static let position = 0
    static let texcoord = 1
    static let normal   = 2
}

struct Texturei {
    static let colori = 0
}

enum RendererError: Error {
    case badVertex
}

public struct Uniforms {
    var projectionMat: matrix_float4x4
    var viewMat: matrix_float4x4
}

public struct UniformEyes {
    // a uniform for each eye
    var eye: (Uniforms, Uniforms)
}
