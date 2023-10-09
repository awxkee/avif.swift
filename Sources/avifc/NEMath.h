//
//  NEMath.h
//
//
//  Created by Radzivon Bartoshyk on 08/10/2023.
//

#ifndef NEMath_h
#define NEMath_h

#ifdef __cplusplus

#if __arm64__

#include <arm_neon.h>
#include <vector>
#include <array>

/* Logarithm polynomial coefficients */
static const std::array<float32x4_t, 8> log_tab =
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

__attribute__((always_inline))
static inline float32x4_t vtaylor_polyq_f32(float32x4_t x, const std::array<float32x4_t, 8> &coeffs)
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

__attribute__((always_inline))
static inline float32x4_t prefer_vfmaq_f32(float32x4_t a, float32x4_t b, float32x4_t c)
{
#if __ARM_FEATURE_FMA
    return vfmaq_f32(a, b, c);
#else // __ARM_FEATURE_FMA
    return vmlaq_f32(a, b, c);
#endif // __ARM_FEATURE_FMA
}

__attribute__((always_inline))
static inline float32x4_t vexpq_f32(float32x4_t x)
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

__attribute__((always_inline))
static inline float32x4_t vlogq_f32(float32x4_t x)
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

static inline float32x4_t vlog10q_f32(float32x4_t x)
{
    static const float32x4_t CONST_LN10 = vdupq_n_f32(2.30258509299); // ln(2)
    const float32x4_t v = vlogq_f32(x);
    return vdivq_f32(v, CONST_LN10);
}

__attribute__((always_inline))
static inline float32x4_t vpowq_f32(float32x4_t val, float32x4_t n)
{
    return vexpq_f32(vmulq_f32(n, vlogq_f32(val)));
}

__attribute__((always_inline))
static inline float32x4_t vpowq_f32(float32x4_t t, float power) {
    return vpowq_f32(t, vdupq_n_f32(power));
}

__attribute__((always_inline))
static inline float32x4_t vclampq_n_f32(const float32x4_t t, const float min, const float max) {
    return vmaxq_f32(vminq_f32(t, vdupq_n_f32(max)), vdupq_n_f32(min));
}

__attribute__((always_inline))
static inline float32x4x4_t MatTransponseQF32(const float32x4x4_t matrix)
{
    float32x4_t     row0 = matrix.val[0];
    float32x4_t     row1 = matrix.val[1];
    float32x4_t     row2 = matrix.val[2];
    float32x4_t     row3 = matrix.val[3];

    float32x4x2_t   row01 = vtrnq_f32(row0, row1);
    float32x4x2_t   row23 = vtrnq_f32(row2, row3);

    float32x4x4_t r = {
        vcombine_f32(vget_low_f32(row01.val[0]), vget_low_f32(row23.val[0])),
        vcombine_f32(vget_low_f32(row01.val[1]), vget_low_f32(row23.val[1])),
        vcombine_f32(vget_high_f32(row01.val[0]), vget_high_f32(row23.val[0])),
        vcombine_f32(vget_high_f32(row01.val[1]), vget_high_f32(row23.val[1]))
    };
    return r;
}

__attribute__((always_inline))
static inline float32x4_t vreinhardq_f32(const float32x4_t t) {
    float32x4_t v = vaddq_f32(t, vdupq_n_f32(1.0f));
    return vdivq_f32(t, v);
}

__attribute__((always_inline))
static inline uint32x4_t vhtonlq_u32(const uint32x4_t hostlong) {
    uint8x8_t low = vreinterpret_u8_u32(vget_low_u32(hostlong));
    uint8x8_t high = vreinterpret_u8_u32(vget_high_u32(hostlong));

    low = vrev32_u8(low); // Swap bytes within low 32-bit elements
    high = vrev32_u8(high); // Swap bytes within high 32-bit elements

    uint32x4_t result = vcombine_u32(vreinterpret_u32_u8(low), vreinterpret_u32_u8(high));
    return result;
}

__attribute__((always_inline))
static inline float32x4_t vcopysignq_f32(const float32x4_t dst, const float32x4_t src) {
    // Create a mask where each element is 1 if the sign is negative, otherwise 0
     uint32x4_t mask = vcltq_f32(src, vdupq_n_f32(0.0f));
     // Use vbslq_f32 to copy the sign
     return vbslq_f32(mask, vnegq_f32(dst), dst);
}

__attribute__((always_inline))
static inline float vsumq_f32(const float32x4_t v) {
    float32x2_t r = vadd_f32(vget_high_f32(v), vget_low_f32(v));
    return vget_lane_f32(vpadd_f32(r, r), 0);
}

#endif

#endif // _cplusplus

#endif /* NEMath_h */
