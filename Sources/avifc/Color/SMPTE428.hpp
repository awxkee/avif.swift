//
//  SMPTE428.hpp
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

#ifndef SMPTE428_H
#define SMPTE428_H

#import "Math/MathPowf.hpp"
#import "NEMath.h"

#if __arm64__
#include <arm_neon.h>

__attribute__((always_inline))
static inline float32x4_t SMPTE428ToLinear(const float32x4_t v) {
    const float32x4_t r = vltq_n_f32(v, 0.0f, 0.0f);
    const float mul = 52.37f / 48.0f;
    return vmulq_n_f32(vpowq_f32(r, 2.6f), mul);
}

#endif

float SMPTE428ToLinear(const float value)
{
    if (value < 0.0f) {
        return 0.0f;
    }
    constexpr float scale = 52.37f / 48.0f;
    return powf_c(value, 2.6f) * scale;
}

#endif /* SMPTE428_H */
