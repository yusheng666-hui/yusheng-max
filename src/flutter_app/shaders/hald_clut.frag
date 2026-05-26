#version 320 es

// GPU Hald CLUT + basic image adjustments
// Level-8 Hald: 64x64 pixel 2D CLUT texture
// Input: captured photo (sampler0), Hald CLUT (sampler1)
// Adjustments applied BEFORE CLUT lookup

precision mediump float;

uniform sampler2D inputImage;
uniform sampler2D haldClut;

// Adjustments — uniforms are indexed in declaration order
uniform float uExposure;    // [-2.0, 2.0]
uniform float uContrast;    // [-1.0, 1.0]
uniform float uSaturation;  // [-1.0, 1.0]
uniform float uTemperature; // [-1.0, 1.0]
uniform float uVignette;    // [0.0, 2.0]
uniform vec2  uInputSize;   // render size in logical pixels

out vec4 fragColor;

// BT.601 luma weights
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void main() {
    // Normalize canvas coordinate to [0,1] UV
    vec2 uv = gl_FragCoord.xy / uInputSize;

    // Sample input image
    vec3 color = texture(inputImage, uv).rgb;

    // --- Exposure: multiply by 2^ev ---
    color *= pow(2.0, uExposure);

    // --- Contrast: pivot around 0.5 ---
    color = (color - 0.5) * (1.0 + uContrast) + 0.5;

    // --- Saturation: mix with luminance ---
    float lum = dot(color, LUMA);
    color = mix(vec3(lum), color, 1.0 + uSaturation);

    // --- Temperature: R/B shift (warm = +R/-B, cool = -R/+B) ---
    color.r += uTemperature * 0.15;
    color.b -= uTemperature * 0.15;

    // Clamp to valid range before CLUT lookup
    color = clamp(color, 0.0, 1.0);

    // --- Hald CLUT lookup (Level 8, trilinear interpolation) ---
    // Map each channel [0,1] to sample index [0,7]
    float rIdx = color.r * 7.0;
    float gIdx = color.g * 7.0;
    float bIdx = color.b * 7.0;

    // Integer and fractional parts
    float r0f = floor(rIdx);
    float g0f = floor(gIdx);
    float b0f = floor(bIdx);
    float dr = rIdx - r0f;
    float dg = gIdx - g0f;
    float db = bIdx - b0f;

    float r1f = min(r0f + 1.0, 7.0);
    float g1f = min(g0f + 1.0, 7.0);
    float b1f = min(b0f + 1.0, 7.0);

    // Trilinear interpolation across 8 corners
    vec3 result = vec3(0.0);
    for (int ri = 0; ri < 2; ri++) {
        for (int gi = 0; gi < 2; gi++) {
            for (int bi = 0; bi < 2; bi++) {
                float r = (ri == 0) ? r0f : r1f;
                float g = (gi == 0) ? g0f : g1f;
                float b = (bi == 0) ? b0f : b1f;

                float weight = ((ri == 0) ? (1.0 - dr) : dr)
                             * ((gi == 0) ? (1.0 - dg) : dg)
                             * ((bi == 0) ? (1.0 - db) : db);

                // Hald layout: x = g*8 + b, y = r
                // Use texelFetch with integer coordinates to avoid filtering bleed
                ivec2 haldCoord = ivec2(
                    int(g) * 8 + int(b),
                    int(r)
                );
                haldCoord = clamp(haldCoord, ivec2(0), ivec2(63));
                vec3 clutSample = texelFetch(haldClut, haldCoord, 0).rgb;
                result += clutSample * weight;
            }
        }
    }

    // --- Vignette: darken corners ---
    vec2 center = uv - 0.5;
    float dist = length(center);
    float vignetteFactor = 1.0 - uVignette * dist * dist * 4.0;
    vignetteFactor = clamp(vignetteFactor, 0.0, 1.0);
    result *= vignetteFactor;

    fragColor = vec4(result, 1.0);
}
