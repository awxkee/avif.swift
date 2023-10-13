//
//  PerceptualQuantinizer.mm
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 06/09/2022.
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

// https://review.mlplatform.org/plugins/gitiles/ml/ComputeLibrary/+/6ff3b19ee6120edf015fad8caab2991faa3070af/arm_compute/core/NEON/NEMath.inl
// https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BT.2446-2019-PDF-E.pdf
// https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.2100-2-201807-I!!PDF-E.pdf
// https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BT.2446-2019-PDF-E.pdf

#import <Foundation/Foundation.h>
#import "HDRColorTransfer.h"
#import "Accelerate/Accelerate.h"

#if __has_include(<Metal/Metal.h>)
#import <Metal/Metal.h>
#endif
#import "TargetConditionals.h"

#ifdef __arm64__
#include <arm_neon.h>
#endif

#import "NEMath.h"
#import "Math/FastMath.hpp"
#import "Color/Colorspace.h"
#import "ToneMap/Rec2408ToneMapper.hpp"
#import "ToneMap/LogarithmicToneMapper.hpp"
#import "ToneMap/ReinhardToneMapper.hpp"
#import "ToneMap/ClampToneMapper.hpp"
#import "ToneMap/ReinhardJodieToneMapper.hpp"
#import "half.hpp"
#import "Color/Gamma.hpp"
#import "Color/PQ.hpp"
#import "Color/HLG.hpp"
#import "Color/SMPTE428.hpp"

using namespace std;
using namespace half_float;

constexpr float sdrReferencePoint = 203.0f;

struct TriStim {
    float r;
    float g;
    float b;
};

TriStim ClipToWhite(TriStim* c);

inline float Luma(TriStim &stim, const float* primaries) {
    return stim.r * primaries[0] + stim.g * primaries[1] + stim.b * primaries[2];
}

inline TriStim ClipToWhite(TriStim* c, const float* primaries) {
    float maximum = max(max(c->r, c->g), c->b);
    if (maximum > 1.0f) {
        float l = Luma(*c, primaries);
        c->r *= 1.0f / maximum;
        c->g *= 1.0f / maximum;
        c->b *= 1.0f / maximum;
        TriStim white = { 1.0f, 1.0f, 1.0f };
        float wScale = (1.0f - 1.0f / maximum) * l / Luma(white, primaries);
        white = { 1.0f*wScale, 1.0f*wScale, 1.0f*wScale };
        TriStim black = {0.0f, 0.0f, 0.0f };
        c->r += white.r;
        c->g += white.g;
        c->b += white.b;
    }
    return *c;
}

inline half loadHalf(uint16_t t) {
    half f;
    f.data_ = t;
    return f;
}

void TransferROW_U16HFloats(uint16_t *data, ColorGammaCorrection gammaCorrection, const float* primaries,
                            ToneMapper* toneMapper, TransferFunction transfer, ColorSpaceMatrix* matrix) {
    float r = (float) loadHalf(data[0]);
    float g = (float) loadHalf(data[1]);
    float b = (float) loadHalf(data[2]);
    TriStim smpte;
    if (transfer == PQ) {
        smpte = {ToLinearPQ(r, sdrReferencePoint), ToLinearPQ(g, sdrReferencePoint), ToLinearPQ(b, sdrReferencePoint)};
    } else if (transfer == HLG) {
        smpte = {HLGToLinear(r), HLGToLinear(g), HLGToLinear(b)};
    } else {
        smpte = {SMPTE428ToLinear(r), SMPTE428ToLinear(g), SMPTE428ToLinear(b)};
    }

    r = smpte.r;
    g = smpte.g;
    b = smpte.b;

    toneMapper->Execute(r, g, b);

    if (matrix) {
        matrix->convert(r, g, b);
    }

    if (gammaCorrection == Rec2020) {
        data[0] = half(clamp(LinearRec2020ToRec2020(r), 0.0f, 1.0f)).data_;
        data[1] = half(clamp(LinearRec2020ToRec2020(g), 0.0f, 1.0f)).data_;
        data[2] = half(clamp(LinearRec2020ToRec2020(b), 0.0f, 1.0f)).data_;
    } else if (gammaCorrection == DisplayP3) {
        data[0] = half(clamp(LinearSRGBToSRGB(r), 0.0f, 1.0f)).data_;
        data[1] = half(clamp(LinearSRGBToSRGB(g), 0.0f, 1.0f)).data_;
        data[2] = half(clamp(LinearSRGBToSRGB(b), 0.0f, 1.0f)).data_;
    } else if (gammaCorrection == Rec709) {
        data[0] = half(clamp(LinearITUR709ToITUR709(r), 0.0f, 1.0f)).data_;
        data[1] = half(clamp(LinearITUR709ToITUR709(g), 0.0f, 1.0f)).data_;
        data[2] = half(clamp(LinearITUR709ToITUR709(b), 0.0f, 1.0f)).data_;
    } else {
        data[0] = half(clamp(r, 0.0f, 1.0f)).data_;
        data[1] = half(clamp(g, 0.0f, 1.0f)).data_;
        data[2] = half(clamp(b, 0.0f, 1.0f)).data_;
    }
}

#if __arm64__

__attribute__((always_inline))
inline void SetPixelsRGB(float16x4_t rgb, uint16_t *vector, int components) {
    uint16x4_t t = vreinterpret_u16_f16(rgb);
    vst1_u16(vector, t);
}

__attribute__((always_inline))
inline void SetPixelsRGBU8(const float32x4_t rgb, uint8_t *vector, const float32x4_t maxColors) {
    const float32x4_t zeros = vdupq_n_f32(0);
    const float32x4_t v = vminq_f32(vmaxq_f32(vrndq_f32(vmulq_f32(rgb, maxColors)), zeros), maxColors);
}

__attribute__((always_inline))
inline float32x4_t GetPixelsRGBU8(const float32x4_t rgb, const float32x4_t maxColors) {
    const float32x4_t zeros = vdupq_n_f32(0);
    const float32x4_t v = vminq_f32(vmaxq_f32(vrndq_f32(vmulq_f32(rgb, maxColors)), zeros), maxColors);
    return v;
}

__attribute__((always_inline))
inline float32x4x4_t Transfer(float32x4_t rChan, float32x4_t gChan,
                              float32x4_t bChan,
                              ColorGammaCorrection gammaCorrection,
                              ToneMapper* toneMapper, 
                              TransferFunction transfer,
                              ColorSpaceMatrix* matrix) {
    float32x4x4_t m;
    if (transfer == PQ) {
        float32x4_t pqR = ToLinearPQ(rChan, sdrReferencePoint);
        float32x4_t pqG = ToLinearPQ(gChan, sdrReferencePoint);
        float32x4_t pqB = ToLinearPQ(bChan, sdrReferencePoint);

        m = {
            pqR, pqG, pqB, vdupq_n_f32(0.0f)
        };
    } else if (transfer == HLG) {
        float32x4_t pqR = HLGToLinear(rChan);
        float32x4_t pqG = HLGToLinear(gChan);
        float32x4_t pqB = HLGToLinear(bChan);

        m = {
            pqR, pqG, pqB, vdupq_n_f32(0.0f)
        };
    } else {
        float32x4_t pqR = SMPTE428ToLinear(rChan);
        float32x4_t pqG = SMPTE428ToLinear(gChan);
        float32x4_t pqB = SMPTE428ToLinear(bChan);

        m = {
            pqR, pqG, pqB, vdupq_n_f32(0.0f)
        };
    }
    m = MatTransponseQF32(m);

    float32x4x4_t r = toneMapper->Execute(m);

    if (matrix) {
        r = (*matrix) * r;
    }

    if (gammaCorrection == Rec2020) {
        r.val[0] = vclampq_n_f32(LinearRec2020ToRec2020(r.val[0]), 0.0f, 1.0f);
        r.val[1] = vclampq_n_f32(LinearRec2020ToRec2020(r.val[1]), 0.0f, 1.0f);
        r.val[2] = vclampq_n_f32(LinearRec2020ToRec2020(r.val[2]), 0.0f, 1.0f);
        r.val[3] = vclampq_n_f32(LinearRec2020ToRec2020(r.val[3]), 0.0f, 1.0f);
    } else if (gammaCorrection == DisplayP3) {
        r.val[0] = vclampq_n_f32(LinearSRGBToSRGB(r.val[0]), 0.0f, 1.0f);
        r.val[1] = vclampq_n_f32(LinearSRGBToSRGB(r.val[1]), 0.0f, 1.0f);
        r.val[2] = vclampq_n_f32(LinearSRGBToSRGB(r.val[2]), 0.0f, 1.0f);
        r.val[3] = vclampq_n_f32(LinearSRGBToSRGB(r.val[3]), 0.0f, 1.0f);
    } else if (gammaCorrection == Rec709) {
        r.val[0] = vclampq_n_f32(LinearITUR709ToITUR709(r.val[0]), 0.0f, 1.0f);
        r.val[1] = vclampq_n_f32(LinearITUR709ToITUR709(r.val[1]), 0.0f, 1.0f);
        r.val[2] = vclampq_n_f32(LinearITUR709ToITUR709(r.val[2]), 0.0f, 1.0f);
        r.val[3] = vclampq_n_f32(LinearITUR709ToITUR709(r.val[3]), 0.0f, 1.0f);
    } else {
        r.val[0] = vclampq_n_f32(r.val[0], 0.0f, 1.0f);
        r.val[1] = vclampq_n_f32(r.val[1], 0.0f, 1.0f);
        r.val[2] = vclampq_n_f32(r.val[2], 0.0f, 1.0f);
        r.val[3] = vclampq_n_f32(r.val[3], 0.0f, 1.0f);
    }

    return r;
}

#endif

void TransferROW_U16(uint16_t *data, float maxColors,
                     ColorGammaCorrection gammaCorrection,
                     float* primaries,
                     ColorSpaceMatrix* matrix) {
    //    auto r = (float) data[0];
    //    auto g = (float) data[1]);
    //    auto b = (float) data[2];
    //    float luma = Luma(ToLinearToneMap(r), ToLinearToneMap(g), ToLinearToneMap(b), primaries);
    //    TriStim smpte = {ToLinearPQ(r), ToLinearPQ(g), ToLinearPQ(b)};
    //    float pqLuma = Luma(smpte, primaries);
    //    float scale = luma / pqLuma;
    //    data[0] = float_to_half((float) smpte.r * scale);
    //    data[1] = float_to_half((float) smpte.g * scale);
    //    data[2] = float_to_half((float) smpte.b * scale);
}

void TransferROW_U8(uint8_t *data, float maxColors,
                    ColorGammaCorrection gammaCorrection,
                    ToneMapper* toneMapper,
                    TransferFunction transfer,
                    ColorSpaceMatrix* matrix) {
    auto r = (float) data[0] / (float) maxColors;
    auto g = (float) data[1] / (float) maxColors;
    auto b = (float) data[2] / (float) maxColors;
    TriStim smpte;
    if (transfer == PQ) {
        smpte = {ToLinearPQ(r, sdrReferencePoint), ToLinearPQ(g, sdrReferencePoint), ToLinearPQ(b, sdrReferencePoint)};
    } else if (transfer == HLG) {
        smpte = {HLGToLinear(r), HLGToLinear(g), HLGToLinear(b)};
    } else {
        smpte = {SMPTE428ToLinear(r), SMPTE428ToLinear(g), SMPTE428ToLinear(b)};
    }

    r = smpte.r;
    g = smpte.g;
    b = smpte.b;

    toneMapper->Execute(r, g, b);

    if (matrix) {
        matrix->convert(r, g, b);
    }

    if (gammaCorrection == Rec2020) {
        r = LinearRec2020ToRec2020(r);
        g = LinearRec2020ToRec2020(g);
        b = LinearRec2020ToRec2020(b);
    } else if (gammaCorrection == DisplayP3) {
        r = LinearSRGBToSRGB(r);
        g = LinearSRGBToSRGB(g);
        b = LinearSRGBToSRGB(b);
    } else if (gammaCorrection == Rec709) {
        r = LinearITUR709ToITUR709(r);
        g = LinearITUR709ToITUR709(g);
        b = LinearITUR709ToITUR709(b);
    }

    data[0] = (uint8_t) clamp((float) round(r * maxColors), 0.0f, maxColors);
    data[1] = (uint8_t) clamp((float) round(g * maxColors), 0.0f, maxColors);
    data[2] = (uint8_t) clamp((float) round(b * maxColors), 0.0f, maxColors);
}

@implementation HDRColorTransfer : NSObject

#if __arm64__

+(void)transferNEONF16:(nonnull uint8_t*)data stride:(int)stride width:(int)width height:(int)height 
                 depth:(int)depth primaries:(float*)primaries
                 space:(ColorGammaCorrection)space
                 components:(int)components
                 toneMapper:(ToneMapper*)toneMapper
                 function:(TransferFunction)function
                 matrix:(ColorSpaceMatrix*)matrix {
    auto ptr = reinterpret_cast<uint8_t *>(data);

    dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_apply(height, concurrentQueue, ^(size_t y) {

        auto ptr16 = reinterpret_cast<uint16_t *>(ptr + y * stride);
        int x;
        for (x = 0; x + 8 < width / 2; x += 8) {
            if (components == 4) {
                float16x8x4_t rgbVector = vld4q_f16(reinterpret_cast<const float16_t *>(ptr16));

                float32x4_t rChannelsLow = vcvt_f32_f16(vget_low_f16(rgbVector.val[0]));
                float32x4_t rChannelsHigh = vcvt_f32_f16(vget_high_f16(rgbVector.val[0]));
                float32x4_t gChannelsLow = vcvt_f32_f16(vget_low_f16(rgbVector.val[1]));
                float32x4_t gChannelsHigh = vcvt_f32_f16(vget_high_f16(rgbVector.val[1]));
                float32x4_t bChannelsLow = vcvt_f32_f16(vget_low_f16(rgbVector.val[2]));
                float32x4_t bChannelsHigh = vcvt_f32_f16(vget_high_f16(rgbVector.val[2]));
                float16x8_t aChannels = rgbVector.val[3];

                float32x4x4_t low = Transfer(rChannelsLow, gChannelsLow, bChannelsLow, space, toneMapper, function, matrix);

                low = MatTransponseQF32(low);

                float16x4_t rw1 = vcvt_f16_f32(low.val[0]);
                float16x4_t rw2 = vcvt_f16_f32(low.val[1]);
                float16x4_t rw3 = vcvt_f16_f32(low.val[2]);

                float32x4x4_t high = Transfer(rChannelsHigh, gChannelsHigh, bChannelsHigh, space, toneMapper, function, matrix);
                high = MatTransponseQF32(high);
                float16x4_t rw12 = vcvt_f16_f32(high.val[0]);
                float16x4_t rw22 = vcvt_f16_f32(high.val[1]);
                float16x4_t rw32 = vcvt_f16_f32(high.val[2]);
                float16x8_t finalRow1 = vcombine_f16(rw1, rw12);
                float16x8_t finalRow2 = vcombine_f16(rw2, rw22);
                float16x8_t finalRow3 = vcombine_f16(rw3, rw32);

                float16x8x4_t rw = { finalRow1, finalRow2, finalRow3, aChannels };
                vst4q_f16(reinterpret_cast<float16_t*>(ptr16), rw);
            } else {
                float16x8x3_t rgbVector = vld3q_f16(reinterpret_cast<const float16_t *>(ptr16));

                float32x4_t rChannelsLow = vcvt_f32_f16(vget_low_f16(rgbVector.val[0]));
                float32x4_t rChannelsHigh = vcvt_f32_f16(vget_high_f16(rgbVector.val[0]));
                float32x4_t gChannelsLow = vcvt_f32_f16(vget_low_f16(rgbVector.val[1]));
                float32x4_t gChannelsHigh = vcvt_f32_f16(vget_high_f16(rgbVector.val[1]));
                float32x4_t bChannelsLow = vcvt_f32_f16(vget_low_f16(rgbVector.val[2]));
                float32x4_t bChannelsHigh = vcvt_f32_f16(vget_high_f16(rgbVector.val[2]));

                float32x4x4_t low = Transfer(rChannelsLow, gChannelsLow, bChannelsLow, space, toneMapper, function, matrix);

                float32x4x4_t m = {
                    low.val[0], low.val[1], low.val[2], low.val[3]
                };
                m = MatTransponseQF32(m);

                float32x4x4_t high = Transfer(rChannelsHigh, gChannelsHigh, bChannelsHigh, space, toneMapper, function, matrix);

                float32x4x4_t highM = {
                    high.val[0], high.val[1], high.val[2], high.val[3]
                };
                highM = MatTransponseQF32(highM);

                float16x8_t mergedR = vcombine_f16(vcvt_f16_f32(m.val[0]), vcvt_f16_f32(highM.val[0]));
                float16x8_t mergedG = vcombine_f16(vcvt_f16_f32(m.val[1]), vcvt_f16_f32(highM.val[1]));
                float16x8_t mergedB = vcombine_f16(vcvt_f16_f32(m.val[2]), vcvt_f16_f32(highM.val[2]));
                float16x8x3_t merged = { mergedR, mergedG, mergedB };
                vst3q_f16(reinterpret_cast<float16_t*>(ptr16), merged);
            }

            ptr16 += components*8;
        }

        for (; x < width; ++x) {
            TransferROW_U16HFloats(ptr16, space, primaries, toneMapper, function, matrix);
            ptr16 += components;
        }
    });
}

+(void)transferNEONU8:(nonnull uint8_t*)data
               stride:(int)stride width:(int)width height:(int)height depth:(int)depth
            primaries:(float*)primaries space:(ColorGammaCorrection)space components:(int)components
           toneMapper:(ToneMapper*)toneMapper
             function:(TransferFunction)function 
               matrix:(ColorSpaceMatrix*)matrix {
    auto ptr = reinterpret_cast<uint8_t *>(data);

    const float32x4_t mask = {1.0f, 1.0f, 1.0f, 0.0};

    const auto maxColors = powf(2, (float) depth) - 1;
    const auto mColors = vdupq_n_f32(maxColors);

    const float colorScale = 1.0f / float((1 << depth) - 1);

    const float32x4_t vMaxColors = vdupq_n_f32(maxColors);

    dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_apply(height, concurrentQueue, ^(size_t y) {
        auto ptr16 = reinterpret_cast<uint8_t *>(ptr + y * stride);
        int x;
        int pixels = 16;
        for (x = 0; x + pixels < width; x += pixels) {
            if (components == 4) {
                uint8x16x4_t rgbChannels = vld4q_u8(ptr16);

                uint8x8_t rChannelsLow = vget_low_u8(rgbChannels.val[0]);
                uint8x8_t rChannelsHigh = vget_high_f16(rgbChannels.val[0]);
                uint8x8_t gChannelsLow = vget_low_u8(rgbChannels.val[1]);
                uint8x8_t gChannelsHigh = vget_high_f16(rgbChannels.val[1]);
                uint8x8_t bChannelsLow = vget_low_u8(rgbChannels.val[2]);
                uint8x8_t bChannelsHigh = vget_high_f16(rgbChannels.val[2]);

                uint16x8_t rLowU16 = vmovl_u8(rChannelsLow);
                uint16x8_t gLowU16 = vmovl_u8(gChannelsLow);
                uint16x8_t bLowU16 = vmovl_u8(bChannelsLow);
                uint16x8_t rHighU16 = vmovl_u8(rChannelsHigh);
                uint16x8_t gHighU16 = vmovl_u8(gChannelsHigh);
                uint16x8_t bHighU16 = vmovl_u8(bChannelsHigh);

                float32x4_t rLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(rLowU16))), colorScale);
                float32x4_t gLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(gLowU16))), colorScale);
                float32x4_t bLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(bLowU16))), colorScale);

                float32x4x4_t low = Transfer(rLow, gLow, bLow, space, toneMapper, function, matrix);
                float32x4_t rw1 = GetPixelsRGBU8(low.val[0], vMaxColors);
                float32x4_t rw2 = GetPixelsRGBU8(low.val[1], vMaxColors);
                float32x4_t rw3 = GetPixelsRGBU8(low.val[2], vMaxColors);
                float32x4_t rw4 = GetPixelsRGBU8(low.val[3], vMaxColors);
                float32x4x4_t transposedLowLow = {
                    rw1, rw2, rw3, rw4
                };
                transposedLowLow = MatTransponseQF32(transposedLowLow);

                rLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(rLowU16))), colorScale);
                gLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(gLowU16))), colorScale);
                bLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(bLowU16))), colorScale);

                low = Transfer(rLow, gLow, bLow, space, toneMapper, function, matrix);
                rw1 = GetPixelsRGBU8(low.val[0], vMaxColors);
                rw2 = GetPixelsRGBU8(low.val[1], vMaxColors);
                rw3 = GetPixelsRGBU8(low.val[2], vMaxColors);
                rw4 = GetPixelsRGBU8(low.val[3], vMaxColors);
                float32x4x4_t transposedLowHigh = {
                    rw1, rw2, rw3, rw4
                };
                transposedLowHigh = MatTransponseQF32(transposedLowHigh);

                rLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(rHighU16))), colorScale);
                gLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(gHighU16))), colorScale);
                bLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(bHighU16))), colorScale);

                low = Transfer(rLow, gLow, bLow, space, toneMapper, function, matrix);
                rw1 = GetPixelsRGBU8(low.val[0], vMaxColors);
                rw2 = GetPixelsRGBU8(low.val[1], vMaxColors);
                rw3 = GetPixelsRGBU8(low.val[2], vMaxColors);
                rw4 = GetPixelsRGBU8(low.val[3], vMaxColors);
                float32x4x4_t transposedHighLow = {
                    rw1, rw2, rw3, rw4
                };
                transposedHighLow = MatTransponseQF32(transposedHighLow);

                rLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(rHighU16))), colorScale);
                gLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(gHighU16))), colorScale);
                bLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(bHighU16))), colorScale);

                low = Transfer(rLow, gLow, bLow, space, toneMapper, function, matrix);
                rw1 = GetPixelsRGBU8(low.val[0], vMaxColors);
                rw2 = GetPixelsRGBU8(low.val[1], vMaxColors);
                rw3 = GetPixelsRGBU8(low.val[2], vMaxColors);
                rw4 = GetPixelsRGBU8(low.val[3], vMaxColors);
                float32x4x4_t transposedHighHigh = {
                    rw1, rw2, rw3, rw4
                };
                transposedHighHigh = MatTransponseQF32(transposedHighHigh);

                uint8x8_t row1u16 = vqmovn_u16(vcombine_u16(vqmovn_u32(vcvtq_u32_f32(transposedLowLow.val[0])),
                                                            vqmovn_u32(vcvtq_u32_f32(transposedLowHigh.val[0]))));
                uint8x8_t row2u16 = vqmovn_u16(vcombine_u16(vqmovn_u32(vcvtq_u32_f32(transposedHighLow.val[0])),
                                                            vqmovn_u32(vcvtq_u32_f32(transposedHighHigh.val[0]))));
                uint8x16_t rowR = vcombine_u8(row1u16, row2u16);

                row1u16 = vqmovn_u16(vcombine_u16(vqmovn_u32(vcvtq_u32_f32(transposedLowLow.val[1])),
                                                  vqmovn_u32(vcvtq_u32_f32(transposedLowHigh.val[1]))));
                row2u16 = vqmovn_u16(vcombine_u16(vqmovn_u32(vcvtq_u32_f32(transposedHighLow.val[1])),
                                                  vqmovn_u32(vcvtq_u32_f32(transposedHighHigh.val[1]))));
                uint8x16_t rowG = vcombine_u8(row1u16, row2u16);

                row1u16 = vqmovn_u16(vcombine_u16(vqmovn_u32(vcvtq_u32_f32(transposedLowLow.val[2])),
                                                  vqmovn_u32(vcvtq_u32_f32(transposedLowHigh.val[2]))));
                row2u16 = vqmovn_u16(vcombine_u16(vqmovn_u32(vcvtq_u32_f32(transposedHighLow.val[2])),
                                                  vqmovn_u32(vcvtq_u32_f32(transposedHighHigh.val[2]))));
                uint8x16_t rowB = vcombine_u8(row1u16, row2u16);
                uint8x16x4_t result = {rowR, rowG, rowB, rgbChannels.val[3]};
                vst4q_u8(ptr16, result);
            } else {
                uint8x16x3_t rgbChannels = vld3q_u8(ptr16);

                uint8x8_t rChannelsLow = vget_low_u8(rgbChannels.val[0]);
                uint8x8_t rChannelsHigh = vget_high_f16(rgbChannels.val[0]);
                uint8x8_t gChannelsLow = vget_low_u8(rgbChannels.val[1]);
                uint8x8_t gChannelsHigh = vget_high_f16(rgbChannels.val[1]);
                uint8x8_t bChannelsLow = vget_low_u8(rgbChannels.val[2]);
                uint8x8_t bChannelsHigh = vget_high_f16(rgbChannels.val[2]);

                uint16x8_t rLowU16 = vmovl_u8(rChannelsLow);
                uint16x8_t gLowU16 = vmovl_u8(gChannelsLow);
                uint16x8_t bLowU16 = vmovl_u8(bChannelsLow);
                uint16x8_t rHighU16 = vmovl_u8(rChannelsHigh);
                uint16x8_t gHighU16 = vmovl_u8(gChannelsHigh);
                uint16x8_t bHighU16 = vmovl_u8(bChannelsHigh);

                float32x4_t rLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(rLowU16))), colorScale);
                float32x4_t gLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(gLowU16))), colorScale);
                float32x4_t bLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(bLowU16))), colorScale);

                float32x4x4_t low = Transfer(rLow, gLow, bLow, space, toneMapper, function, matrix);
                float32x4_t rw1 = GetPixelsRGBU8(low.val[0], vMaxColors);
                float32x4_t rw2 = GetPixelsRGBU8(low.val[1], vMaxColors);
                float32x4_t rw3 = GetPixelsRGBU8(low.val[2], vMaxColors);
                float32x4_t rw4 = GetPixelsRGBU8(low.val[3], vMaxColors);
                float32x4x4_t transposedLowLow = {
                    rw1, rw2, rw3, rw4
                };
                transposedLowLow = MatTransponseQF32(transposedLowLow);

                rLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(rLowU16))), colorScale);
                gLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(gLowU16))), colorScale);
                bLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(bLowU16))), colorScale);

                low = Transfer(rLow, gLow, bLow, space, toneMapper, function, matrix);
                rw1 = GetPixelsRGBU8(low.val[0], vMaxColors);
                rw2 = GetPixelsRGBU8(low.val[1], vMaxColors);
                rw3 = GetPixelsRGBU8(low.val[2], vMaxColors);
                rw4 = GetPixelsRGBU8(low.val[3], vMaxColors);
                float32x4x4_t transposedLowHigh = {
                    rw1, rw2, rw3, rw4
                };
                transposedLowHigh = MatTransponseQF32(transposedLowHigh);

                rLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(rHighU16))), colorScale);
                gLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(gHighU16))), colorScale);
                bLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(bHighU16))), colorScale);

                low = Transfer(rLow, gLow, bLow, space, toneMapper, function, matrix);
                rw1 = GetPixelsRGBU8(low.val[0], vMaxColors);
                rw2 = GetPixelsRGBU8(low.val[1], vMaxColors);
                rw3 = GetPixelsRGBU8(low.val[2], vMaxColors);
                rw4 = GetPixelsRGBU8(low.val[3], vMaxColors);
                float32x4x4_t transposedHighLow = {
                    rw1, rw2, rw3, rw4
                };
                transposedHighLow = MatTransponseQF32(transposedHighLow);

                rLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(rHighU16))), colorScale);
                gLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(gHighU16))), colorScale);
                bLow = vmulq_n_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(bHighU16))), colorScale);

                low = Transfer(rLow, gLow, bLow, space, toneMapper, function, matrix);
                rw1 = GetPixelsRGBU8(low.val[0], vMaxColors);
                rw2 = GetPixelsRGBU8(low.val[1], vMaxColors);
                rw3 = GetPixelsRGBU8(low.val[2], vMaxColors);
                rw4 = GetPixelsRGBU8(low.val[3], vMaxColors);
                float32x4x4_t transposedHighHigh = {
                    rw1, rw2, rw3, rw4
                };
                transposedHighHigh = MatTransponseQF32(transposedHighHigh);

                uint8x8_t row1u16 = vqmovn_u16(vcombine_u16(vqmovn_u32(vcvtq_u32_f32(transposedLowLow.val[0])),
                                                            vqmovn_u32(vcvtq_u32_f32(transposedLowHigh.val[0]))));
                uint8x8_t row2u16 = vqmovn_u16(vcombine_u16(vqmovn_u32(vcvtq_u32_f32(transposedHighLow.val[0])),
                                                            vqmovn_u32(vcvtq_u32_f32(transposedHighHigh.val[0]))));
                uint8x16_t rowR = vcombine_u8(row1u16, row2u16);

                row1u16 = vqmovn_u16(vcombine_u16(vqmovn_u32(vcvtq_u32_f32(transposedLowLow.val[1])),
                                                  vqmovn_u32(vcvtq_u32_f32(transposedLowHigh.val[1]))));
                row2u16 = vqmovn_u16(vcombine_u16(vqmovn_u32(vcvtq_u32_f32(transposedHighLow.val[1])),
                                                  vqmovn_u32(vcvtq_u32_f32(transposedHighHigh.val[1]))));
                uint8x16_t rowG = vcombine_u8(row1u16, row2u16);

                row1u16 = vqmovn_u16(vcombine_u16(vqmovn_u32(vcvtq_u32_f32(transposedLowLow.val[2])),
                                                  vqmovn_u32(vcvtq_u32_f32(transposedLowHigh.val[2]))));
                row2u16 = vqmovn_u16(vcombine_u16(vqmovn_u32(vcvtq_u32_f32(transposedHighLow.val[2])),
                                                  vqmovn_u32(vcvtq_u32_f32(transposedHighHigh.val[2]))));
                uint8x16_t rowB = vcombine_u8(row1u16, row2u16);
                uint8x16x3_t result = {rowR, rowG, rowB};
                vst3q_u8(ptr16, result);
            }

            ptr16 += components*pixels;
        }

        for (; x < width; ++x) {
            TransferROW_U8(ptr16, maxColors, space, toneMapper, function, matrix);
            ptr16 += components;
        }
    });
}
#endif

+(void)transfer:(nonnull uint8_t*)data stride:(int)stride width:(int)width height:(int)height
            U16:(bool)U16 depth:(int)depth half:(bool)half primaries:(float*)primaries
            components:(int)components gammaCorrection:(ColorGammaCorrection)gammaCorrection
            function:(TransferFunction)function matrix:(ColorSpaceMatrix*)matrix
            profile:(ColorSpaceProfile*)profile {
    auto ptr = reinterpret_cast<uint8_t *>(data);
    ToneMapper* toneMapper = new Rec2408ToneMapper(1000.0f, profile->whitePointNits, profile->whitePointNits, profile->lumaCoefficients);
#if __arm64__
    if (U16 && half) {
        [self transferNEONF16:reinterpret_cast<uint8_t*>(data) stride:stride width:width height:height
                        depth:depth primaries:primaries space:gammaCorrection
                   components:components toneMapper:toneMapper function:function matrix:matrix];
        delete toneMapper;
        return;
    }
    if (!U16) {
        [self transferNEONU8:reinterpret_cast<uint8_t*>(data) stride:stride width:width height:height
                       depth:depth primaries:primaries space:gammaCorrection
                  components:components toneMapper:toneMapper function:function matrix:matrix];
        delete toneMapper;
        return;
    }
#endif
    auto maxColors = pow(2, (float) depth) - 1;

    dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_apply(height, concurrentQueue, ^(size_t y) {
        if (U16) {
            auto ptr16 = reinterpret_cast<uint16_t *>(ptr + y * stride);
            for (int x = 0; x < width; ++x) {
                if (half) {
                    TransferROW_U16HFloats(ptr16, gammaCorrection, primaries, toneMapper, function, matrix);
                } else {
                    TransferROW_U16(ptr16, maxColors, gammaCorrection, primaries, matrix);
                }
                ptr16 += components;
            }
        } else {
            auto ptr16 = reinterpret_cast<uint8_t *>(ptr + y * stride);
            for (int x = 0; x < width; ++x) {
                TransferROW_U8(ptr16, maxColors, gammaCorrection, toneMapper, function, matrix);
                ptr16 += components;
            }
        }
    });

    delete toneMapper;
}
@end
