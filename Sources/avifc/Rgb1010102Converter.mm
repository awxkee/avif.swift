//
//  Rgb1010102Converter.mm
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 10/09/2022.
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


#import <Foundation/Foundation.h>
#import "Rgb1010102Converter.h"
#import "Accelerate/Accelerate.h"
#import <vector>
#import "half.hpp"
#import "NEMath.h"

#if __arm64__
#include <arm_neon.h>
#endif

using namespace half_float;
using namespace std;

inline half loadHalf1010102(uint16_t t) {
    half f;
    f.data_ = t;
    return f;
}

@implementation Rgb1010102Converter: NSObject

+(bool)F16ToU16:(nonnull uint8_t*)src dst:(nonnull uint8_t*)dst stride:(int)stride width:(int)width height:(int)height components:(int)components {
    uint8_t* dstTrail = reinterpret_cast<uint8_t*>(dst);
    uint8_t* mSrc = reinterpret_cast<uint8_t*>(src);
    int newStride = width * sizeof(uint8_t) * 4;
    const float scale = 1.0f / float((1 << 10) - 1);
    const float maxColors = pow(2.0f, 10.0f) - 1;
    const float maxAlpha = 3;
    const half halfAlpha = half(3);
    uint16_t alpha = 3;
#if __arm64__
    const float32x4_t vecMaxColors = vdupq_n_f32(pow(2.0f, 10.0f) - 1);
    const uint32x4_t vecAlpha = vdupq_n_u32(alpha);
    auto allowNeon = components == 3 || components == 4;
#endif
    for (int y = 0; y < height; ++y) {
        uint16_t* row = reinterpret_cast<uint16_t*>(mSrc);
        uint32_t* dst16 = reinterpret_cast<uint32_t*>(dstTrail);
        int x = 0;

#if __arm64__
        int pixelCount = 8;
        if (allowNeon) {
            for (; x + pixelCount < width; x+=pixelCount) {
                float16x8x4_t rgb;
                if (components == 4) {
                    rgb = vld4q_f16(reinterpret_cast<float16_t*>(row));
                } else {
                    float16x8x3_t rgbx3 = vld3q_f16(reinterpret_cast<float16_t*>(row));
                    rgb = { rgbx3.val[0], rgbx3.val[1], rgbx3.val[2], vdupq_n_f16(halfAlpha) };
                }

                uint32x4_t rLow = vcvtq_u32_f32(
                                                vclampq_n_f32(vrndq_f32(vmulq_f32(vcvt_f32_f16(vget_low_f16(rgb.val[0])), vecMaxColors)),
                                                              0, maxColors)
                                                );
                uint32x4_t rHigh = vcvtq_u32_f32(
                                                 vclampq_n_f32(vrndq_f32(vmulq_f32(vcvt_f32_f16(vget_high_f16(rgb.val[0])), vecMaxColors)),
                                                               0, maxColors)
                                                 );

                uint32x4_t gLow = vcvtq_u32_f32(
                                                vclampq_n_f32(vrndq_f32(vmulq_f32(vcvt_f32_f16(vget_low_f16(rgb.val[1])), vecMaxColors)),
                                                              0, maxColors)
                                                );
                uint32x4_t gHigh = vcvtq_u32_f32(
                                                 vclampq_n_f32(vrndq_f32(vmulq_f32(vcvt_f32_f16(vget_high_f16(rgb.val[1])), vecMaxColors)),
                                                               0, maxColors)
                                                 );

                uint32x4_t bLow = vcvtq_u32_f32(
                                                vclampq_n_f32(vrndq_f32(vmulq_f32(vcvt_f32_f16(vget_low_f16(rgb.val[2])), vecMaxColors)),
                                                              0, maxColors)
                                                );
                uint32x4_t bHigh = vcvtq_u32_f32(
                                                 vclampq_n_f32(vrndq_f32(vmulq_f32(vcvt_f32_f16(vget_high_f16(rgb.val[2])), vecMaxColors)),
                                                               0, maxColors)
                                                 );

                uint32x4_t aLow = vcvtq_u32_f32(
                                                vclampq_n_f32(vrndq_f32(vmulq_n_f32(vcvt_f32_f16(vget_low_f16(rgb.val[3])), maxAlpha)), 0, maxAlpha)
                                                );
                uint32x4_t aHigh = vcvtq_u32_f32(
                                                 vclampq_n_f32(vrndq_f32(vmulq_n_f32(vcvt_f32_f16(vget_high_f16(rgb.val[3])), maxAlpha)), 0, maxAlpha)
                                                 );

                uint32x4_t pixelsLow = vhtonlq_u32(vorrq_u32(vorrq_u32(vshlq_n_u32(rLow, 22), vshlq_n_u32(gLow, 12)),
                                                             vorrq_u32(vshlq_n_u32(bLow, 2), aLow)));
                uint32x4_t pixelsHigh = vhtonlq_u32(vorrq_u32(vorrq_u32(vshlq_n_u32(rHigh, 22), vshlq_n_u32(gHigh, 12)),
                                                              vorrq_u32(vshlq_n_u32(bHigh, 2), aHigh)));
                vst1q_u32(reinterpret_cast<uint32_t*>(dst16), pixelsLow);
                vst1q_u32(reinterpret_cast<uint32_t*>(dst16 + 4), pixelsHigh);
                row += components * pixelCount;
                dst16 += pixelCount;
            }
        }
#endif
        for (; x < width; ++x) {
            uint32_t a;
            if (components == 4) {
                a = static_cast<uint32_t>(clamp(round((float)loadHalf1010102(row[3]) * maxAlpha), 0.0f, maxColors));
            } else {
                a = static_cast<uint32_t>(alpha);
            }
            uint32_t r = static_cast<uint32_t>(clamp(round((float)loadHalf1010102(row[0]) * maxColors), 0.0f, maxColors));
            uint32_t g = static_cast<uint32_t>(clamp(round((float)loadHalf1010102(row[1]) * maxColors), 0.0f, maxColors));
            uint32_t b = static_cast<uint32_t>(clamp(round((float)loadHalf1010102(row[2]) * maxColors), 0.0f, maxColors));
            dst16[0] = htonl((r << 22) | (g << 12) | (b << 2) | a);

            row += components;
            dst16 += 1;
        }
        mSrc += stride;
        dstTrail += newStride;
    }
    return true;
}

+(bool)F16ToRGBA1010102:(nonnull uint8_t*)data dst:(nonnull uint8_t*)dst stride:(nonnull int*)stride width:(int)width height:(int)height components:(int)components {
    if (![self F16ToU16:data dst:dst stride:*stride width:width height:height components:components]) {
        return false;
    }

    int rgb1010102Stride = width * sizeof(uint8_t) * 4;
    *stride = rgb1010102Stride;
    return true;
}

@end
