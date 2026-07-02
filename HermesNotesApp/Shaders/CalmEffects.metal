// Deliberately small Metal layer: two SwiftUI-stitchable shaders that add
// texture where flat fills would feel dead, and nothing else. Both are
// disabled under Reduce Motion / Reduce Transparency (see ShaderEffects.swift).

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Very subtle animated paper grain, layered over the Today briefing card.
// `intensity` should stay well under 0.04 — this is texture, not an effect.
[[ stitchable ]] half4 calmGrain(float2 position, half4 color, float time, float intensity) {
    float grain = hash21(position + fract(time * 0.05) * 100.0);
    float delta = (grain - 0.5) * intensity;
    return half4(color.rgb + half3(delta), color.a);
}

// Soft radial wash behind an Eisenhower quadrant: a single GPU pass instead
// of stacked translucent layers, keeping drag-and-drop fluid.
// `size` is the quadrant's bounds; `tint` its quiet accent.
[[ stitchable ]] half4 quadrantWash(float2 position, half4 color, float2 size, half4 tint) {
    float2 uv = position / max(size, float2(1.0, 1.0));
    float dist = distance(uv, float2(0.5, 0.18));
    float falloff = smoothstep(0.95, 0.0, dist);
    half3 washed = mix(color.rgb, tint.rgb, half(falloff) * tint.a);
    return half4(washed, color.a);
}
