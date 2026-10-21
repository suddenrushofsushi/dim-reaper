#include <metal_stdlib>
using namespace metal;

struct VSOut {
    float4 position [[position]];
    float2 uv;
};

// Full-screen triangle trick: three vertices generated procedurally from vertex_id,
// covering the entire viewport with one triangle (no vertex buffer needed).
vertex VSOut fullscreen_vertex(uint vid [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    VSOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = (positions[vid] + 1.0) * 0.5;
    return out;
}

// v1: solid tint with per-fragment color. uv is plumbed through so v2 shaders can sample
// time-varying or position-varying effects without touching the vertex stage.
fragment float4 tint_fragment(VSOut in [[stage_in]],
                              constant float4 &tintColor [[buffer(0)]]) {
    // Premultiplied output: rgb scaled by alpha.
    return float4(tintColor.rgb * tintColor.a, tintColor.a);
}
