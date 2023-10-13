//
//  Gamma.hpp
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 12/10/2023.
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

#ifndef HLG_H
#define HLG_H

#include "Math/FastMath.hpp"

#if __arm64__
#include <arm_neon.h>
#include "NEMath.h"

__attribute__((always_inline))
static inline float32x4_t HLGToLinear(const float32x4_t v) {
    const float32x4_t level = vdupq_n_f32(0.5f);

    uint32x4_t mask = vcgtq_f32(v, level);
    uint32x4_t maskHigh = vcltq_f32(v, level);

    constexpr float a = 0.17883277f;
    constexpr float b = 0.28466892f;
    constexpr float c = 0.55991073f;

    const float32x4_t vDivVec = vrecpeq_f32(vdupq_n_f32(a));

    float32x4_t high = vdivq_f32(vaddq_f32(vexpq_f32(vmulq_f32(vsubq_f32(v, vdupq_n_f32(c)), vDivVec)), vdupq_n_f32(b)), vdupq_n_f32(12.0f));
    float32x4_t low = vmulq_n_f32(vmulq_f32(v, v), 1.0f/3.0f);

    low = vbslq_f32(mask, vdupq_n_f32(0), low);
    high = vbslq_f32(maskHigh, vdupq_n_f32(0), high);

    return vaddq_f32(low, high);
}

#endif

static inline float HLGToLinear(float value)
{
    if (value < 0.0f)
    {
        return 0.0f;
    }

    // These constants are from the ITU-R BT.2100 specification:
    // https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.2100-2-201807-I!!PDF-E.pdf
    constexpr float a = 0.17883277f;
    constexpr float b = 0.28466892f;
    constexpr float c = 0.55991073f;

    if (value > 0.5f)
    {
        value = (expf_c((value - c) / a) + b) / 12.0f;
    }
    else
    {
        const float den = 1.0f / 3.0f;
        value = (value * value) * den;
    }

    return value;
}


#endif /* HLG_H */
