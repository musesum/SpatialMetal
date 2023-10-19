
#include <metal_stdlib>
#include <simd/simd.h>
#include "ShaderTypes.h"

using namespace metal;

struct EarthConstants {
    float4x4 earthMat;
};

vertex VertexOut vertexEarth
(
 VertexIn                in     [[ stage_in ]],
 ushort                  ampId  [[ amplification_id ]],
 constant UniformEyes    &eyes  [[ buffer(uniformEyei) ]])
{
    VertexOut out;

    Uniforms uniforms = eyes.eye[ampId];

    out.position = (uniforms.projectionMat *
                    uniforms.viewMat *
                    float4(in.position.xyz, 1.0));

    out.normal = (uniforms.viewMat *
                  float4(in.normal, 0.0f)).xyz;

    out.texCoord = in.texCoord;
    out.texCoord.x = 1.0f - out.texCoord.x; // Flip uvs horizontally to match Model I/O
    return out;
}

fragment float4 fragmentEarth
(
 VertexOut       out [[ stage_in ]],
 texture2d<half> tex [[ texture(colori) ]])
{
    constexpr sampler samplr(coord::normalized,
                             filter::linear,
                             mip_filter::none,
                             address::repeat);

    half4 color = tex.sample(samplr, out.texCoord);
    return float4(color);
}
