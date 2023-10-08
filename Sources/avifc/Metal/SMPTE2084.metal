//
//  SMTE2084.metal
//  SMPTE 2084 Transfer function
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 07/09/2023.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#include <metal_stdlib>
using namespace metal;

// https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BT.2446-2019-PDF-E.pdf
// https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.2100-2-201807-I!!PDF-E.pdf
// https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BT.2446-2019-PDF-E.pdf

float transferBt2020(float c) {
    float mod = abs(c);

    float alpha = 1.09929682680944; // 10 * Math.pow(beta, 0.55)
    float beta = 0.018053968510807;
    if (mod < beta * 4.5)
      c = c / 4.5;
    else
      c = pow((mod + alpha - 1) / alpha, 1/0.45);

    if (c < beta)
      c = 4.5 * c;
    else
      c = alpha * pow(c, 0.45) - (alpha - 1);
    return c;
}

constant float betaRec2020 = 0.018053968510807f;
constant float alphaRec2020 = 1.09929682680944f;

float bt2020GammaCorrection(float linear) {
    if (0 <= betaRec2020 && linear < betaRec2020) {
        return 4.5 * linear;
    } else if (betaRec2020 <= linear && linear < 1) {
        return alphaRec2020 * pow(linear, 0.45) - (alphaRec2020 - 1);
    }
    return linear;
}

kernel void SMPTE2084(texture2d<float, access::read_write> texture [[texture(0)]],
                      const device int* depth [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]])
{
    float4 originalColor = texture.read(gid);
    float4 color = max(originalColor, 0);
    color.a = 0;
    float m1 = (2610.0 / 4096.0) / 4.0;
    float m2 = (2523.0 / 4096.0) * 128.0;
    float c1 = 3424.0 / 4096.0;
    float c2 = (2413.0 / 4096.0) * 32.0;
    float c3 = (2392.0 / 4096.0) * 32.0;
    float4 p = pow(max(color, float4(0.0)), 1.0 / m2);
    float4 denom = pow(max(p - c1, 0.0) / (c2 - c3 * p), 1.0 / m1);
    color = float4(float3(denom * 10000.0 / 203.0f), 1.0);

    const float Ld = 1000.0f / 203.0f;
    float a = 1.0f / (Ld*Ld);
    float b1 = 1.f / 1.0f;

    float maximum = max(max(color.r, color.g), color.b);
    if (maximum > 0) {
        float shScale = (1.f + a * maximum) / (1.f + b1 * maximum);
        color *= shScale;
    }

    color.a = originalColor.a;

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
    float m1 = (2610.0 / 4096.0) / 4.0;
    float m2 = (2523.0 / 4096.0) * 128.0;
    float c1 = 3424.0 / 4096.0;
    float c2 = (2413.0 / 4096.0) * 32.0;
    float c3 = (2392.0 / 4096.0) * 32.0;
    float4 p = pow(max(color, float4(0.0)), 1.0 / m2);
    float4 denom = pow(max(p - c1, 0.0) / (c2 - c3 * p), 1.0 / m1);
    color = float4(float3(denom * 10000.0 / 80), 1.0);

    const float Ld = 1000.0f / 203.0f;
    float a = 1.0f / (Ld*Ld);
    float b1 = 1.f / 1.0f;

    float maximum = max(max(color.r, color.g), color.b);
    if (maximum > 0) {
        float shScale = (1.f + a * maximum) / (1.f + b1 * maximum);
        color *= shScale;
    }

    color.a = originalColor.a;
    float4 outColorF = clamp(color * maxColors, 0, maxColors);
    ushort4 outColor = ushort4(outColorF);

    texture.write(outColor, gid);
}
