//
//  ReinhardJodieToneMapper.cpp
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 10/10/2023.
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

#include "ReinhardJodieToneMapper.hpp"
#include "NEMath.h"

#if defined(__clang__)
#pragma clang fp contract(fast) exceptions(ignore) reassociate(on)
#endif

template <typename T>
T lerp(const T& a, const T& b, float t) {
    return a + t * (b - a);
}

#if __arm64__

__attribute__((flatten))
inline float32x4_t lerpNEON(const float32x4_t a, const float32x4_t b, float32x4_t t) {
    return vmlaq_f32(a, t, vsubq_f32(b, a));
}

__attribute__((flatten))
inline float32x4_t reinhardNEON(const float32x4_t v, const float lumaMaximum, const bool useExtended) {
    if (useExtended) {
        return vdivq_f32(vmulq_f32(v, vaddq_f32(vdupq_n_f32(1), vdivq_f32(v, vdupq_n_f32(lumaMaximum * lumaMaximum)))),
                         vaddq_f32(vdupq_n_f32(1.0f), v));
    }
    return vdivq_f32(v, vaddq_f32(vdupq_n_f32(1.0f), v));
}
#endif

float ReinhardJodieToneMapper::Luma(const float r, const float g, const float b) {
    return r * lumaVec[0] + g * lumaVec[1] + b * lumaVec[2];
}

float ReinhardJodieToneMapper::reinhard(const float v) {
    if (useExtended) {
        float Ld = (v * (1 + (v / (lumaMaximum * lumaMaximum)))) / (1 + v);
        return Ld;
    }
    return v / (1.0f + v);
}

void ReinhardJodieToneMapper::Execute(float& r, float& g, float& b) {
    r *= exposure;
    g *= exposure;
    b *= exposure;
    const float Lin = Luma(r, g, b);
    const float tv[3] = { r / (1.0f + r), g / (1.0f + g) , b / (1.0f + b)};
    r = lerp(r / (1.0f + Lin), tv[0], tv[0]);
    g = lerp(g / (1.0f + Lin), tv[1], tv[1]);
    b = lerp(b / (1.0f + Lin), tv[2], tv[2]);
}

#if __arm64__

float32x4_t ReinhardJodieToneMapper::Execute(const float32x4_t m) {
    const float32x4_t v = vmulq_n_f32(m, exposure);
    const float luma = vaddvq_f32(vmulq_f32(v, vLumaVec));

    const float32x4_t tv = vdivq_f32(v, vaddq_f32(vdupq_n_f32(1.0f), v));
    const float32x4_t in = vdivq_f32(v, vdupq_n_f32(1.0f + luma));
    return lerpNEON(in, tv, tv);
}

float32x4x4_t ReinhardJodieToneMapper::Execute(const float32x4x4_t m) {
    const float32x4x4_t exposured = {
        vmulq_n_f32(m.val[0], exposure),
        vmulq_n_f32(m.val[1], exposure),
        vmulq_n_f32(m.val[2], exposure),
        vmulq_n_f32(m.val[3], exposure),
    };
    float32x4_t Lin = {
        vaddvq_f32(vmulq_f32(exposured.val[0], vLumaVec)),
        vaddvq_f32(vmulq_f32(exposured.val[1], vLumaVec)),
        vaddvq_f32(vmulq_f32(exposured.val[2], vLumaVec)),
        vaddvq_f32(vmulq_f32(exposured.val[3], vLumaVec)),
    };
    Lin = vaddq_f32(Lin, vdupq_n_f32(1.0f));
    Lin = vrecpeq_f32(Lin);

    const float32x4_t tv1 = vdivq_f32(exposured.val[0], vaddq_f32(vdupq_n_f32(1.0f), exposured.val[0]));
    const float32x4_t in1 = vmulq_laneq_f32(exposured.val[0], Lin, 0);

    const float32x4_t tv2 = vdivq_f32(exposured.val[1], vaddq_f32(vdupq_n_f32(1.0f), exposured.val[1]));
    const float32x4_t in2 = vmulq_laneq_f32(exposured.val[1], Lin, 1);

    const float32x4_t tv3 = vdivq_f32(exposured.val[2], vaddq_f32(vdupq_n_f32(1.0f), exposured.val[2]));
    const float32x4_t in3 = vmulq_laneq_f32(exposured.val[2], Lin, 2);

    const float32x4_t tv4 = vdivq_f32(exposured.val[3], vaddq_f32(vdupq_n_f32(1.0f), exposured.val[3]));
    const float32x4_t in4 = vmulq_laneq_f32(exposured.val[3], Lin, 3);

    const float32x4x4_t res = {
        lerpNEON(in1, tv1, tv1),
        lerpNEON(in2, tv2, tv2),
        lerpNEON(in3, tv3, tv3),
        lerpNEON(in4, tv4, tv4)
    };
    return res;
}
#endif
