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
#import "PerceptualQuantinizer.h"
#import "Accelerate/Accelerate.h"

#if __has_include(<Metal/Metal.h>)
#import <Metal/Metal.h>
#endif
#import "TargetConditionals.h"

#ifdef __arm64__
#include <arm_neon.h>
#endif

uint as_uint(const float x) {
    return *(uint *) &x;
}

float as_float(const uint x) {
    return *(float *) &x;
}

uint16_t float_to_half(
                       const float x) { // IEEE-754 16-bit floating-point format (without infinity): 1-5-10, exp-15, +-131008.0, +-6.1035156E-5, +-5.9604645E-8, 3.311 digits
    const uint b =
    as_uint(x) + 0x00001000; // round-to-nearest-even: add last bit after truncated mantissa
    const uint e = (b & 0x7F800000) >> 23; // exponent
    const uint m = b &
    0x007FFFFF; // mantissa; in line below: 0x007FF000 = 0x00800000-0x00001000 = decimal indicator flag - initial rounding
    return (b & 0x80000000) >> 16 | (e > 112) * ((((e - 112) << 10) & 0x7C00) | m >> 13) |
    ((e < 113) & (e > 101)) * ((((0x007FF000 + m) >> (125 - e)) + 1) >> 1) |
    (e > 143) * 0x7FFF; // sign : normalized : denormalized : saturate
}

float half_to_float(
                    const uint16_t x) { // IEEE-754 16-bit floating-point format (without infinity): 1-5-10, exp-15, +-131008.0, +-6.1035156E-5, +-5.9604645E-8, 3.311 digits
    const uint e = (x & 0x7C00) >> 10; // exponent
    const uint m = (x & 0x03FF) << 13; // mantissa
    const uint v = as_uint((float) m)
    >> 23; // evil log2 bit hack to count leading zeros in denormalized format
    return as_float((x & 0x8000) << 16 | (e != 0) * ((e + 112) << 23 | m) | ((e == 0) & (m != 0)) *
                    ((v - 37) << 23 |
                     ((m << (150 - v)) &
                      0x007FE000))); // sign : normalized : denormalized
}

float whitePoint = 180.0f;

float ToLinearPQ(float v) {
    v = std::max(0.0f, v);
    float m1 = (2610.0f / 4096.0f) / 4.0f;
    float m2 = (2523.0f / 4096.0f) * 128.0f;
    float c1 = 3424.0f / 4096.0f;
    float c2 = (2413.0f / 4096.0f) * 32.0f;
    float c3 = (2392.0f / 4096.0f) * 32.0f;
    float p = pow(v, 1.0f / m2);
    v = powf(std::max(p - c1, 0.0f) / (c2 - c3 * p), 1.0f / m1);
    v *= 10000.0f / whitePoint;
    return v;
}

struct TriStim {
    float r;
    float g;
    float b;
};

TriStim ClipToWhite(TriStim* c);

float Luma(TriStim &stim) {
    return stim.r * 0.2627f + stim.g * 0.6780f + stim.b * 0.0593f;
}

float Luma(float r, float g, float b) {
    return r * 0.2627f + g * 0.6780f + b * 0.0593f;
}

float clampf(float value, float min, float max) {
    return fmin(fmax(value, min), max);
}

void TransferROW_U16HFloats(uint16_t *data) {
    auto r = (float) half_to_float(data[0]);
    auto g = (float) half_to_float(data[1]);
    auto b = (float) half_to_float(data[2]);
    TriStim smpte = {ToLinearPQ(r), ToLinearPQ(g), ToLinearPQ(b)};
    data[0] = float_to_half((float) smpte.r);
    data[1] = float_to_half((float) smpte.g);
    data[2] = float_to_half((float) smpte.b);
}

#if __arm64__

/* Logarithm polynomial coefficients */
const std::array<float32x4_t, 8> log_tab =
{
    {
        vdupq_n_f32(-2.29561495781f),
        vdupq_n_f32(-2.47071170807f),
        vdupq_n_f32(-5.68692588806f),
        vdupq_n_f32(-0.165253549814f),
        vdupq_n_f32(5.17591238022f),
        vdupq_n_f32(0.844007015228f),
        vdupq_n_f32(4.58445882797f),
        vdupq_n_f32(0.0141278216615f),
    }
};

static const uint32_t exp_f32_coeff[] =
{
    0x3f7ffff6, // x^1: 0x1.ffffecp-1f
    0x3efffedb, // x^2: 0x1.fffdb6p-2f
    0x3e2aaf33, // x^3: 0x1.555e66p-3f
    0x3d2b9f17, // x^4: 0x1.573e2ep-5f
    0x3c072010, // x^5: 0x1.0e4020p-7f
};

inline float32x4_t vtaylor_polyq_f32(float32x4_t x, const std::array<float32x4_t, 8> &coeffs)
{
    float32x4_t A   = vmlaq_f32(coeffs[0], coeffs[4], x);
    float32x4_t B   = vmlaq_f32(coeffs[2], coeffs[6], x);
    float32x4_t C   = vmlaq_f32(coeffs[1], coeffs[5], x);
    float32x4_t D   = vmlaq_f32(coeffs[3], coeffs[7], x);
    float32x4_t x2  = vmulq_f32(x, x);
    float32x4_t x4  = vmulq_f32(x2, x2);
    float32x4_t res = vmlaq_f32(vmlaq_f32(A, B, x2), vmlaq_f32(C, D, x2), x4);
    return res;
}

inline float32x4_t prefer_vfmaq_f32(float32x4_t a, float32x4_t b, float32x4_t c)
{
#if __ARM_FEATURE_FMA
    return vfmaq_f32(a, b, c);
#else // __ARM_FEATURE_FMA
    return vmlaq_f32(a, b, c);
#endif // __ARM_FEATURE_FMA
}

inline float32x4_t vexpq_f32(float32x4_t x)
{
    const auto c1 = vreinterpretq_f32_u32(vdupq_n_u32(exp_f32_coeff[0]));
    const auto c2 = vreinterpretq_f32_u32(vdupq_n_u32(exp_f32_coeff[1]));
    const auto c3 = vreinterpretq_f32_u32(vdupq_n_u32(exp_f32_coeff[2]));
    const auto c4 = vreinterpretq_f32_u32(vdupq_n_u32(exp_f32_coeff[3]));
    const auto c5 = vreinterpretq_f32_u32(vdupq_n_u32(exp_f32_coeff[4]));

    const auto shift      = vreinterpretq_f32_u32(vdupq_n_u32(0x4b00007f)); // 2^23 + 127 = 0x1.0000fep23f
    const auto inv_ln2    = vreinterpretq_f32_u32(vdupq_n_u32(0x3fb8aa3b)); // 1 / ln(2) = 0x1.715476p+0f
    const auto neg_ln2_hi = vreinterpretq_f32_u32(vdupq_n_u32(0xbf317200)); // -ln(2) from bits  -1 to -19: -0x1.62e400p-1f
    const auto neg_ln2_lo = vreinterpretq_f32_u32(vdupq_n_u32(0xb5bfbe8e)); // -ln(2) from bits -20 to -42: -0x1.7f7d1cp-20f

    const auto inf       = vdupq_n_f32(std::numeric_limits<float>::infinity());
    const auto max_input = vdupq_n_f32(88.37f); // Approximately ln(2^127.5)
    const auto zero      = vdupq_n_f32(0.f);
    const auto min_input = vdupq_n_f32(-86.64f); // Approximately ln(2^-125)

    // Range reduction:
    //   e^x = 2^n * e^r
    // where:
    //   n = floor(x / ln(2))
    //   r = x - n * ln(2)
    //
    // By adding x / ln(2) with 2^23 + 127 (shift):
    //   * As FP32 fraction part only has 23-bits, the addition of 2^23 + 127 forces decimal part
    //     of x / ln(2) out of the result. The integer part of x / ln(2) (i.e. n) + 127 will occupy
    //     the whole fraction part of z in FP32 format.
    //     Subtracting 2^23 + 127 (shift) from z will result in the integer part of x / ln(2)
    //     (i.e. n) because the decimal part has been pushed out and lost.
    //   * The addition of 127 makes the FP32 fraction part of z ready to be used as the exponent
    //     in FP32 format. Left shifting z by 23 bits will result in 2^n.
    const auto z     = prefer_vfmaq_f32(shift, x, inv_ln2);
    const auto n     = z - shift;
    const auto scale = vreinterpretq_f32_u32(vreinterpretq_u32_f32(z) << 23); // 2^n

    // The calculation of n * ln(2) is done using 2 steps to achieve accuracy beyond FP32.
    // This outperforms longer Taylor series (3-4 tabs) both in term of accuracy and performance.
    const auto r_hi = prefer_vfmaq_f32(x, n, neg_ln2_hi);
    const auto r    = prefer_vfmaq_f32(r_hi, n, neg_ln2_lo);

    // Compute the truncated Taylor series of e^r.
    //   poly = scale * (1 + c1 * r + c2 * r^2 + c3 * r^3 + c4 * r^4 + c5 * r^5)
    const auto r2 = r * r;

    const auto p1     = c1 * r;
    const auto p23    = prefer_vfmaq_f32(c2, c3, r);
    const auto p45    = prefer_vfmaq_f32(c4, c5, r);
    const auto p2345  = prefer_vfmaq_f32(p23, p45, r2);
    const auto p12345 = prefer_vfmaq_f32(p1, p2345, r2);

    auto poly = prefer_vfmaq_f32(scale, p12345, scale);

    // Handle underflow and overflow.
    poly = vbslq_f32(vcltq_f32(x, min_input), zero, poly);
    poly = vbslq_f32(vcgtq_f32(x, max_input), inf, poly);

    return poly;
}

inline float32x4_t vlogq_f32(float32x4_t x)
{
    static const int32x4_t   CONST_127 = vdupq_n_s32(127);           // 127
    static const float32x4_t CONST_LN2 = vdupq_n_f32(0.6931471805f); // ln(2)

    // Extract exponent
    int32x4_t   m   = vsubq_s32(vreinterpretq_s32_u32(vshrq_n_u32(vreinterpretq_u32_f32(x), 23)), CONST_127);
    float32x4_t val = vreinterpretq_f32_s32(vsubq_s32(vreinterpretq_s32_f32(x), vshlq_n_s32(m, 23)));

    // Polynomial Approximation
    float32x4_t poly = vtaylor_polyq_f32(val, log_tab);

    // Reconstruct
    poly = vmlaq_f32(poly, vcvtq_f32_s32(m), CONST_LN2);

    return poly;
}

inline float32x4_t vpowq_f32(float32x4_t val, float32x4_t n)
{
    return vexpq_f32(vmulq_f32(n, vlogq_f32(val)));
}

inline float32x4_t vpowq_f32(float32x4_t t, float power) {
    return vpowq_f32(t, vdupq_n_f32(power));
}

// Constants
const static float32x4_t zero = vdupq_n_f32(0.0f);
const static float m1 = (2610.0f / 4096.0f) / 4.0f;
const static float m2 = (2523.0f / 4096.0f) * 128.0f;
const static float32x4_t c1 = vdupq_n_f32(3424.0f / 4096.0f);
const static float32x4_t c2 = vdupq_n_f32((2413.0f / 4096.0f) * 32.0f);
const static float32x4_t c3 = vdupq_n_f32((2392.0f / 4096.0f) * 32.0f);
const static float m2Power = 1.0f / m2;
const static float m1Power = 1.0f / m1;

const static float lumaScale = 10000.0f / whitePoint;

inline float32x4_t ToLinearPQ(float32x4_t v) {

    /*
     *  float p = pow(v, 1.0f / m2);
     v = powf(std::max(p - c1, 0.0f) / (c2 - c3 * p), 1.0f / m1);
     v *= 10000.0f / 650.0f;
     */

    // Calculate p and intermediate values
    float32x4_t p = vpowq_f32(vmaxq_f32(v, zero), m2Power);
    // Calculate v
    return vmulq_n_f32(vpowq_f32(vdivq_f32(vmaxq_f32(vsubq_f32(p, c1), zero), vmlsq_f32(c2, c3, p)), m1Power),
                       lumaScale);
}

const static float32x4_t linearM = vdupq_n_f32(2.3f);
const static float32x4_t linearM1 = vdupq_n_f32(0.8f);
const static float32x4_t linearM2 = vdupq_n_f32(0.2f);

inline float32x4_t ToLinearToneMap(float32x4_t v) {
    // Apply the function element-wise to the vector
    float32x4_t max_zero = vmaxq_f32(v, zero);

    return vminq_f32(vmulq_f32(vpowq_f32(max_zero, 2.8f), linearM), vmlaq_f32(max_zero, linearM1, linearM2));
}

static const float32x4_t lumaCoefficients = {0.2627f, 0.6780f, 0.0593f, 0.0f}; // Weighting coefficients

inline float NeonLuma(float32x4_t vector) {
    // Multiply the RGB channels by the coefficients
    float32x4_t luma = vmulq_f32(vector, lumaCoefficients);
    float32x2_t sum_halves = vadd_f32(vget_high_f32(luma), vget_low_f32(luma));

    // Extract the result as a float
    float32_t result = vget_lane_f32(sum_halves, 0);
    return result;
}

float32x4_t white = {1.0f, 1.0f, 1.0f, 1.0f};
const static float LumaWhite = NeonLuma(white);
const static float32x4_t LumaDup = vdupq_n_f32(LumaWhite);

inline float32x4_t ClipToWhite(float32x4_t v) {
    float max_value = vmaxnmvq_f32(v);

    if (max_value > 1.0f) {
        float scaler = 1.0f / max_value;
        float luma = NeonLuma(v);
        float32x4_t white = {1.0f, 1.0f, 1.0f, 1.0f};
        float dx = 1.0f - scaler;
        white = vdivq_f32(vmulq_n_f32(vmulq_n_f32(white, dx), luma), LumaDup);
        //        float32x4_t black = {0.0f, 0.0f, 0.0f, 0.0f};
        v = vaddq_f32(vmulq_n_f32(v, scaler), white);
    }
    return v;
}

inline void SetPixelsRGB(float16x4_t rgb, uint16_t *vector) {
    uint16x4_t t = vreinterpret_u16_f16(rgb);
    vector[0] = vget_lane_u16(t, 0);
    vector[1] = vget_lane_u16(t, 1);
    vector[2] = vget_lane_u16(t, 2);
}

inline void SetPixelsRGBU8(float32x4_t rgb, uint8_t *vector, float maxColors) {
    vector[0] = (uint8_t) clampf((rgb[0] * maxColors), 0, maxColors);
    vector[1] = (uint8_t) clampf((rgb[1] * maxColors), 0, maxColors);
    vector[2] = (uint8_t) clampf((rgb[2] * maxColors), 0, maxColors);
}

inline float32x4_t Transfer(float32x4_t rgb) {
    float32x4_t pq = ToLinearPQ(rgb);
    return pq;
}

#endif

void TransferROW_U16(uint16_t *data, float maxColors) {
    auto r = (float) data[0] / (float) maxColors;
    auto g = (float) data[1] / (float) maxColors;
    auto b = (float) data[2] / (float) maxColors;
    TriStim smpte = {ToLinearPQ(r), ToLinearPQ(g), ToLinearPQ(b)};
    data[0] = (uint16_t) (float) smpte.r * maxColors;
    data[1] = (uint16_t) (float) smpte.g * maxColors;
    data[2] = (uint16_t) (float) smpte.b * maxColors;
}

void TransferROW_U8(uint8_t *data, float maxColors) {
    auto r = (float) data[0] / (float) maxColors;
    auto g = (float) data[1] / (float) maxColors;
    auto b = (float) data[2] / (float) maxColors;
    TriStim smpte = {ToLinearPQ(r), ToLinearPQ(g), ToLinearPQ(b)};
    data[0] = (uint8_t) clampf((float) smpte.r * maxColors, 0, maxColors);
    data[1] = (uint8_t) clampf((float) smpte.g * maxColors, 0, maxColors);
    data[2] = (uint8_t) clampf((float) smpte.b * maxColors, 0, maxColors);
}

@implementation PerceptualQuantinizer : NSObject

#if __arm64__

+(void)transferNEONF16:(nonnull uint8_t*)data stride:(int)stride width:(int)width height:(int)height depth:(int)depth {
    auto ptr = reinterpret_cast<uint8_t *>(data);

    float32x4_t mask = {1.0f, 1.0f, 1.0f, 0.0};

    dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_apply(height, concurrentQueue, ^(size_t y) {
        auto ptr16 = reinterpret_cast<uint16_t *>(ptr + y * stride);
        int x;
        for (x = 0; x + 2 < width; x += 2) {
            float16x8_t rgbVector = vld1q_f16(reinterpret_cast<const __fp16 *>(ptr16));

            float32x4_t rgbChannelsLow = vmulq_f32(vcvt_f32_f16(vget_low_f16(rgbVector)), mask);
            float32x4_t rgbChannelsHigh = vmulq_f32(vcvt_f32_f16(vget_high_f16(rgbVector)), mask);
            
            float32x4_t low = Transfer(rgbChannelsLow);
            float16x4_t lowHalf = vcvt_f16_f32(low);
            SetPixelsRGB(lowHalf, ptr16);

            float32x4_t high = Transfer(rgbChannelsHigh);
            float16x4_t highHalf = vcvt_f16_f32(high);
            SetPixelsRGB(highHalf, ptr16 + 4);

            ptr16 += 8;
        }

        for (; x < width; ++x) {
            TransferROW_U16HFloats(ptr16);
            ptr16 += 4;
        }
    });
}

+(void)transferNEONU8:(nonnull uint8_t*)data stride:(int)stride width:(int)width height:(int)height depth:(int)depth {
    auto ptr = reinterpret_cast<uint8_t *>(data);

    float32x4_t mask = {1.0f, 1.0f, 1.0f, 0.0};

    auto maxColors = powf(2, (float) depth) - 1;
    auto mColors = vdupq_n_f32(maxColors);

    dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_apply(height, concurrentQueue, ^(size_t y) {
        auto ptr16 = reinterpret_cast<uint8_t *>(ptr + y * stride);
        int x;
        for (x = 0; x + 4 < width; x += 4) {
            uint8x16_t rgbChannels = vld1q_u8(ptr16);

            uint8x8_t low_data = vget_low_u8(rgbChannels);
            uint8x8_t high_data = vget_high_u8(rgbChannels);

            uint16x8_t intermediateVector = vmovl_u8(low_data); // Widen to uint16x8_t

            float32x4_t rgbC1 = vmulq_f32(vdivq_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(intermediateVector))), mColors), mask);
            float32x4_t C1 = Transfer(rgbC1);
            SetPixelsRGBU8(C1, ptr16, maxColors);

            float32x4_t rgbC2 = vmulq_f32(vdivq_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(intermediateVector))), mColors), mask);
            float32x4_t C2 = Transfer(rgbC2);
            SetPixelsRGBU8(C2, ptr16 + 4, maxColors);

            uint16x8_t intermediateVectorHigh = vmovl_u8(high_data); // Widen to uint16x8_t
            float32x4_t rgbC3 = vmulq_f32(vdivq_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(intermediateVectorHigh))), mColors), mask);
            float32x4_t C3 = Transfer(rgbC3);
            SetPixelsRGBU8(C3, ptr16 + 8, maxColors);

            float32x4_t rgbC4 = vmulq_f32(vdivq_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(intermediateVectorHigh))), mColors), mask);
            float32x4_t C4 = Transfer(rgbC4);
            SetPixelsRGBU8(C4, ptr16 + 12, maxColors);

            ptr16 += 16;
        }

        for (; x < width; ++x) {
            TransferROW_U8(ptr16, maxColors);
            ptr16 += 4;
        }
    });
}
#endif

+(bool)transferMetal: (nonnull uint8_t*)data stride:(int)stride width:(int)width height:(int)height
                 U16:(bool)U16
               depth:(int)depth
                half:(bool)half {
    // Always unavailable on simulator, there is not reason to try
#if TARGET_OS_SIMULATOR
    return false;
#endif
#if __has_include(<Metal/Metal.h>)
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        return false;
    }

    NSError *error = nil;
    NSBundle *bundle = [NSBundle bundleForClass:[PerceptualQuantinizer class]];

    id<MTLLibrary> library = [device newDefaultLibraryWithBundle:bundle error:&error];
    if (error) {
        return false;
    }

    auto functionName = @"SMPTE2084";
    if (U16 && !half) {
        functionName = @"SMPTE2084U16";
    } else if (!U16) {
        functionName = @"SMPTE2084U16";
    }

    id<MTLFunction> kernelFunction = [library newFunctionWithName:functionName];
    if (!kernelFunction) {
        return false;
    }

    id<MTLCommandQueue> commandQueue = [device newCommandQueue];
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    if (error) {
        return false;
    }

    MTLComputePipelineDescriptor *pipelineDesc = [[MTLComputePipelineDescriptor alloc] init];
    pipelineDesc.computeFunction = kernelFunction;
    id<MTLComputePipelineState> pipelineState = [device newComputePipelineStateWithFunction:kernelFunction error:&error];
    if (error) {
        return false;
    }

    auto pixelFormat = MTLPixelFormatRGBA16Float;
    if (U16 && !half) {
        pixelFormat = MTLPixelFormatRGBA16Uint;
    } else if (!U16) {
        pixelFormat = MTLPixelFormatRGBA8Uint;
    }
    auto textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:pixelFormat
                                                                                width:width height:height mipmapped:false];
    [textureDescriptor setUsage:MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite];
    auto texture = [device newTextureWithDescriptor:textureDescriptor];
    if (!texture) {
        return false;
    }
    auto region = MTLRegionMake2D(0, 0, width, height);
    [texture replaceRegion:region mipmapLevel:0 withBytes:data bytesPerRow:stride];

    NSUInteger dataSize = 4 * width * height * (U16 ? sizeof(uint16_t) : sizeof(uint8_t));

    NSUInteger bufferSize = sizeof(int);
    id<MTLBuffer> depthBuffer = [device newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
    int* depthPointer = (int *)[depthBuffer contents];
    *depthPointer = depth;

    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    [computeEncoder setComputePipelineState:pipelineState];
    [computeEncoder setTexture:texture atIndex:0];
    [computeEncoder setBuffer:depthBuffer offset:0 atIndex:0];

    MTLSize threadsPerThreadgroup = MTLSizeMake(8, 8, 1);
    MTLSize threadgroups = MTLSizeMake((width + 7) / 8, (height + 7) / 8, 1);
    [computeEncoder dispatchThreadgroups:threadgroups threadsPerThreadgroup:threadsPerThreadgroup];
    [computeEncoder endEncoding];

    // Commit the command buffer
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    [texture getBytes:data bytesPerRow:stride bytesPerImage:dataSize fromRegion:region mipmapLevel:0 slice:0];
    return true;
#else
    return false;
#endif
}

+(void)transfer:(nonnull uint8_t*)data stride:(int)stride width:(int)width height:(int)height
            U16:(bool)U16 depth:(int)depth half:(bool)half {

    auto ptr = reinterpret_cast<uint8_t *>(data);
    if ([self transferMetal:data stride:stride width:width height:height U16:U16 depth:depth half:half]) {
        return;
    }
#if __arm64__
    if (U16 && half) {
        [self transferNEONF16:reinterpret_cast<uint8_t*>(data) stride:stride width:width height:height depth:depth];
    }
    if (!U16) {
        [self transferNEONU8:reinterpret_cast<uint8_t*>(data) stride:stride width:width height:height depth:depth];
    }
    return;
#endif
    auto maxColors = powf(2, (float) depth) - 1;

    dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_apply(height, concurrentQueue, ^(size_t y) {
        if (U16) {
            auto ptr16 = reinterpret_cast<uint16_t *>(ptr + y * stride);
            for (int x = 0; x < width; ++x) {
                if (half) {
                    TransferROW_U16HFloats(ptr16);
                } else {
                    TransferROW_U16(ptr16, maxColors);
                }
                ptr16 += 4;
            }
        } else {
            auto ptr16 = reinterpret_cast<uint8_t *>(ptr + y * stride);
            for (int x = 0; x < width; ++x) {
                TransferROW_U8(ptr16, maxColors);
                ptr16 += 4;
            }
        }
    });
}
@end
