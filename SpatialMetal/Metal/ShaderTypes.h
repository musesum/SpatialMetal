//
//  ShaderTypes.h

#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
typedef metal::int32_t EnumBackingType;
#else
#import <Foundation/Foundation.h>
typedef NSInteger EnumBackingType;
#endif

#include <simd/simd.h>

typedef enum {
    postitioni  = 0,
    normali     = 1,
    texcoordi   = 2,
    uniformEyei = 3,
} Bufferi;

typedef enum {
    position = 0,
    texCoord = 1,
    normal   = 2

} Vertexi;

typedef enum {
    colori = 0,
} Texturei;

struct VertexIn {
    float3 position [[ attribute(position) ]];
    float3 normal   [[ attribute(normal)   ]];
    float2 texCoord [[ attribute(texCoord) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float3 normal;
    float2 texCoord;
};

struct Uniforms {
    matrix_float4x4 projectionMat;
    matrix_float4x4 viewMat;
};
struct UniformEyes {
    Uniforms eye[2];
};

#endif /* ShaderTypes_h */

