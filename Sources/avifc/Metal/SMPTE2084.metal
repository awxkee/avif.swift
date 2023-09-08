//
//  SMTE2084.metal
//  SMPTE 2084 Transfer function
//
//  Created by Radzivon Bartoshyk on 07/09/2023.
//

#include <metal_stdlib>
using namespace metal;

kernel void SMPTE2084(texture2d<float, access::read_write> texture [[texture(0)]],
                      const device int* depth [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]])
{
    float4 originalColor = texture.read(gid);
    float4 color = max(originalColor, 0);
    color.a = 0;
    float4 linearToneMap = min(2.3 * pow(color, float4(2.8)), color / 5.0 + 0.8);
    float4 lumaVec = float4(0.2627, 0.6780, 0.0593, 0.0);
    float luma = dot(linearToneMap, lumaVec);
    if (luma > 0.0) {
        float m1 = (2610.0 / 4096.0) / 4.0;
        float m2 = (2523.0 / 4096.0) * 128.0;
        float c1 = 3424.0 / 4096.0;
        float c2 = (2413.0 / 4096.0) * 32.0;
        float c3 = (2392.0 / 4096.0) * 32.0;
        float4 p = pow(max(color, float4(0.0)), 1.0 / m2);
        float4 denom = pow(max(p - c1, 0.0) / (c2 - c3 * p), 1.0 / m1);
        color = denom * 10000.0 / 80.0f;
        float pq = dot(color, lumaVec);
        if (pq != 0) {
            float scale = luma / pq;
            color = color * scale;
            float cMax = max(max(color.r, color.g), color.b);
            if (cMax > 1.0f) {
                float whiteLuma = dot(color, lumaVec);
                float s = 1.0 / cMax;
                color *= s;
                float4 white = float4(1.0);
                white *= (1.0 - s) * whiteLuma / dot(white, lumaVec);
                color += white - float4(0.0);
            }
        }
    }
    color.a = originalColor.a;
    color.r = (color.r <= 0.0031308) ? (color.r * 12.92) : (pow(color.r, 1.0 / 2.4) * 1.055 - 0.055);
    color.g = (color.g <= 0.0031308) ? (color.g * 12.92) : (pow(color.g, 1.0 / 2.4) * 1.055 - 0.055);
    color.b = (color.b <= 0.0031308) ? (color.b * 12.92) : (pow(color.b, 1.0 / 2.4) * 1.055 - 0.055);

    texture.write(color, gid);
}

kernel void SMPTE2084U16(texture2d<ushort, access::read_write> texture [[texture(0)]],
                         const device int* mDepth [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]])
{
    int depth = *mDepth;
    float maxColors = pow(2.0f, float(depth)) - 1;
    float4 originalColor = float4(texture.read(gid)) / maxColors;
    float4 color = max(originalColor, 0);
    color.a = 0;
    float4 linearToneMap = min(2.3 * pow(color, float4(2.8)), color / 5.0 + 0.8);
    float4 lumaVec = float4(0.2627, 0.6780, 0.0593, 0.0);
    float luma = dot(linearToneMap, lumaVec);
    if (luma > 0.0) {
        float m1 = (2610.0 / 4096.0) / 4.0;
        float m2 = (2523.0 / 4096.0) * 128.0;
        float c1 = 3424.0 / 4096.0;
        float c2 = (2413.0 / 4096.0) * 32.0;
        float c3 = (2392.0 / 4096.0) * 32.0;
        float4 p = pow(max(color, float4(0.0)), 1.0 / m2);
        float4 denom = pow(max(p - c1, 0.0) / (c2 - c3 * p), 1.0 / m1);
        color = denom * 10000.0 / 80.0f;
        float pq = dot(color, lumaVec);
        if (pq != 0) {
            float scale = luma / pq;
            color = color * scale;
            float cMax = max(max(color.r, color.g), color.b);
            if (cMax > 1.0f) {
                float whiteLuma = dot(color, lumaVec);
                float s = 1.0 / cMax;
                color *= s;
                float4 white = float4(1.0);
                white *= (1.0 - s) * whiteLuma / dot(white, lumaVec);
                color += white - float4(0.0);
            }
        }
    }
    color.a = originalColor.a;
    color.r = (color.r <= 0.0031308) ? (color.r * 12.92) : (pow(color.r, 1.0 / 2.4) * 1.055 - 0.055);
    color.g = (color.g <= 0.0031308) ? (color.g * 12.92) : (pow(color.g, 1.0 / 2.4) * 1.055 - 0.055);
    color.b = (color.b <= 0.0031308) ? (color.b * 12.92) : (pow(color.b, 1.0 / 2.4) * 1.055 - 0.055);

    float4 outColorF = max(min(maxColors, color * maxColors), 0);
    ushort4 outColor = ushort4(outColorF);

    texture.write(outColor, gid);
}
