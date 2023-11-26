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

#if defined(__clang__)
#pragma clang fp contract(fast) exceptions(ignore) reassociate(on)
#endif

using namespace half_float;
using namespace std;

inline half loadHalf1010102(uint16_t t) {
    half f;
    f.data_ = t;
    return f;
}

@implementation Rgb1010102Converter: NSObject

+(bool)F16ToRGBA1010102Impl:(nonnull const uint8_t*)src stride:(const int)stride
                        dst:(nonnull uint8_t*)dst dstStride:(const int)dstStride
                      width:(const int)width height:(const int)height components:(const int)components {
    uint8_t* dstTrail = reinterpret_cast<uint8_t*>(dst);
    const uint8_t* mSrc = reinterpret_cast<const uint8_t*>(src);
    const float scale = 1.0f / float((1 << 10) - 1);
    const float maxColors = pow(2.0f, 10.0f) - 1;
    const float maxAlpha = 3;
    uint16_t alpha = 3;
#if __arm64__
    const float16_t maxColorsF16 = pow(2.0f, 10.0f) - 1;
    const float16_t maxAlphaF16 = 3;
    const float16x8_t vecMaxColors = vdupq_n_f16(maxColorsF16);
    auto allowNeon = components == 3 || components == 4;
    const uint32x4_t alphaBitsMask = vdupq_n_u32(0b00000111);
#endif
    for (int y = 0; y < height; ++y) {
        const uint16_t* row = reinterpret_cast<const uint16_t*>(mSrc);
        uint32_t* dst16 = reinterpret_cast<uint32_t*>(dstTrail);
        int x = 0;

#if __arm64__
        int pixelCount = 8;
        if (allowNeon) {
            for (; x + pixelCount < width; x+=pixelCount) {
                float16x8x4_t rgb;
                if (components == 4) {
                    rgb = vld4q_f16(reinterpret_cast<const float16_t*>(row));
                } else {
                    float16x8x3_t rgbx3 = vld3q_f16(reinterpret_cast<const float16_t*>(row));
                    const float16_t h = 1.0f;
                    rgb = { rgbx3.val[0], rgbx3.val[1], rgbx3.val[2], vdupq_n_f16(h) };
                }

                uint16x8x4_t rgbaU16;
                rgbaU16.val[0] = vcvtq_u16_f16(vclampq_n_f16(vrndq_f16(vmulq_f16(rgb.val[0], vecMaxColors)), 0, maxColorsF16));
                rgbaU16.val[1] = vcvtq_u16_f16(vclampq_n_f16(vrndq_f16(vmulq_f16(rgb.val[1], vecMaxColors)), 0, maxColorsF16));
                rgbaU16.val[2] = vcvtq_u16_f16(vclampq_n_f16(vrndq_f16(vmulq_f16(rgb.val[2], vecMaxColors)), 0, maxColorsF16));
                rgbaU16.val[3] = vcvtq_u16_f16(vclampq_n_f16(vrndq_f16(vmulq_n_f16(rgb.val[3], maxAlphaF16)), 0, maxAlphaF16));

                uint32x4_t rLow = vmovl_u16(vget_low_u16(rgbaU16.val[0]));
                uint32x4_t rHigh = vmovl_u16(vget_high_u16(rgbaU16.val[0]));

                uint32x4_t gLow = vmovl_u16(vget_low_u16(rgbaU16.val[1]));
                uint32x4_t gHigh = vmovl_u16(vget_high_u16(rgbaU16.val[1]));

                uint32x4_t bLow = vmovl_u16(vget_low_u16(rgbaU16.val[2]));
                uint32x4_t bHigh = vmovl_u16(vget_high_u16(rgbaU16.val[2]));

                uint32x4_t aLow = vandq_u32(vmovl_u16(vget_low_u16(rgbaU16.val[3])), alphaBitsMask);
                uint32x4_t aHigh = vandq_u32(vmovl_u16(vget_high_u16(rgbaU16.val[3])), alphaBitsMask);

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
        dstTrail += dstStride;
    }
    return true;
}

+(bool)F16ToRGBA1010102:(nonnull const uint8_t*)data stride:(const int)stride
                    dst:(nonnull uint8_t*)dst dstStride:(const int)dstStride
                  width:(const int)width height:(const int)height components:(const int)components {
    if (![self F16ToRGBA1010102Impl:data stride:stride dst:dst dstStride:dstStride width:width height:height components:components]) {
        return false;
    }
    return true;
}

@end
