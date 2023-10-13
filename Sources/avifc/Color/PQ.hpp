//
//  PQ.hpp
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 11/10/2023.
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

#ifndef PQ_h
#define PQ_h

#import "Math/MathPowf.hpp"
#import "NEMath.h"

#if __arm64__
#include <arm_neon.h>

const static float32x4_t zeros = vdupq_n_f32(0);
const static float m1 = (2610.0f / 4096.0f) / 4.0f;
const static float m2 = (2523.0f / 4096.0f) * 128.0f;
const static float32x4_t c1 = vdupq_n_f32(3424.0f / 4096.0f);
const static float32x4_t c2 = vdupq_n_f32((2413.0f / 4096.0f) * 32.0f);
const static float c3 = (2392.0f / 4096.0f) * 32.0f;
const static float m2Power = 1.0f / m2;
const static float m1Power = 1.0f / m1;

__attribute__((always_inline))
static inline float32x4_t ToLinearPQ(const float32x4_t v, const float sdrReferencePoint) {
    const float32x4_t rv = vmaxq_f32(v, zeros);
    float32x4_t p = vpowq_f32(rv, m2Power);
    const float lumaScale = 10000.0f / sdrReferencePoint;
    return vcopysignq_f32(vmulq_n_f32(vpowq_f32(vmulq_f32(vmaxq_f32(vsubq_f32(p, c1), zeros), vrecpeq_f32(vmlsq_n_f32(c2, p, c3))), m1Power),
                                      lumaScale), rv);
}
#endif

static float ToLinearPQ(float v, const float sdrReferencePoint) {
    float o = v;
    v = max(0.0f, v);
    float m1 = (2610.0f / 4096.0f) / 4.0f;
    float m2 = (2523.0f / 4096.0f) * 128.0f;
    float c1 = 3424.0f / 4096.0f;
    float c2 = (2413.0f / 4096.0f) * 32.0f;
    float c3 = (2392.0f / 4096.0f) * 32.0f;
    float p = powf_c(v, 1.0f / m2);
    v = powf_c(max(p - c1, 0.0f) / (c2 - c3 * p), 1.0f / m1);
    v *= 10000.0f / sdrReferencePoint;
    return copysign(v, o);
}

#endif /* PQ_h */
