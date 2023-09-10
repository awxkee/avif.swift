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
    color = denom * 10000.0 / 180;
    color.a = originalColor.a;

    texture.write(color, gid);
}

float HDRLumaToSDR(float hdrLuma) {
    float lHDR = 1000; // Peak HDR luma
    float lSDR = 100; // Peak SDR luma
    float pHDR = 1 + 32*pow(lHDR/10000, 1 / 2.4);
    float Yp = log(1 + (pHDR - 1) * hdrLuma) / log(pHDR);
    float Yc = 0;
    if (Yp >= 0 && Yp <= 0.7399) {
        Yc = 1.0770 * Yp;
    } else if (Yp > 0.7399 && Yp <= 0.9909) {
        Yc = -1.1510*pow(Yp, 2) + (2.7811 * Yp) - 0.6302;
    } else {
        Yc = 0.5 * Yp + 0.5;
    }
    float pSDR = 1 + 32*pow(lSDR/10000, 1/2.4);
    float Ysdr = (pow(pSDR, Yc) - 1) / (pSDR - 1);
    return Ysdr;
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
    color = clamp(denom * 10000.0 / 180, 0.0, 1.0);
    color.a = originalColor.a;
    float4 outColorF = color * maxColors;
    ushort4 outColor = ushort4(outColorF);

    texture.write(outColor, gid);
}
