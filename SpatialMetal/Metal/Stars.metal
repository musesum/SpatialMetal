#include <metal_stdlib>
#include <simd/simd.h>
#include "ShaderTypes.h"

using namespace metal;

vertex VertexOut vertexStars
(
 VertexIn             in     [[ stage_in ]],
 ushort               amp_id [[ amplification_id ]],
 constant UniformEyes &eyes  [[ buffer(uniformEyei) ]])
{
    VertexOut out;

    Uniforms uniforms = eyes.eye[amp_id];
    float4 position = float4(in.position, 1.0);

    out.position = (uniforms.projectionMat *
                    uniforms.viewMat *
                    position);

    out.normal = -in.normal;
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 fragmentStars
(
 VertexOut        out [[ stage_in        ]],
 texture2d<float> tex [[ texture(colori) ]])
{
    constexpr sampler samplr(coord::normalized,
                             filter::linear,
                             mip_filter::none,
                             address::repeat);

    float4 color = tex.sample(samplr, out.texCoord);
    return color;
}
