//
//  Gamma.hpp
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

#ifndef Gamma_hpp
#define Gamma_hpp

#include <stdio.h>

#if defined(__clang__)
#pragma clang fp contract(on) exceptions(ignore) reassociate(on)
#endif

#include <vector>

using namespace std;

constexpr float betaRec2020 = 0.018053968510807f;
constexpr float alphaRec2020 = 1.09929682680944f;

float LinearSRGBToSRGB(const float linearValue);
float LinearRec2020ToRec2020(const float linear);
float dciP3PQGammaCorrection(const float linear);

#if __arm64__

#include <arm_neon.h>
#include "../NEMath.h"

static inline float32x4_t LinearITUR709ToITUR709(const float32x4_t linear) {
    const float32x4_t level = vdupq_n_f32(0.018);

    uint32x4_t mask = vcgtq_f32(linear, level);
    uint32x4_t maskHigh = vcltq_f32(linear, level);

    float32x4_t low = vbslq_f32(mask, vdupq_n_f32(0), linear);
    float32x4_t high = vbslq_f32(maskHigh, vdupq_n_f32(0), linear);
    low = vmulq_n_f32(low, 4.5f);

    high = vsubq_f32(vmulq_n_f32(vpowq_f32(high, 0.45f), 1.099f), vdupq_n_f32(0.099f));
    float32x4_t result = vmaxq_f32(vaddq_f32(low, high), vdupq_n_f32(0));
    return result;
}

static inline float32x4_t LinearSRGBToSRGB(const float32x4_t linear) {
    const float32x4_t level = vdupq_n_f32(0.0031308);

    uint32x4_t mask = vcgtq_f32(linear, level);
    uint32x4_t maskHigh = vcltq_f32(linear, level);

    float32x4_t low = vbslq_f32(mask, vdupq_n_f32(0), linear);
    float32x4_t high = vbslq_f32(maskHigh, vdupq_n_f32(0), linear);
    low = vmulq_n_f32(low, 12.92f);

    high = vsubq_f32(vmulq_n_f32(vpowq_f32(high, 1.0f/2.4f), 1.055f), vdupq_n_f32(0.055f));
    float32x4_t result = vmaxq_f32(vaddq_f32(low, high), vdupq_n_f32(0));
    return result;
}

static inline float32x4_t LinearRec2020ToRec2020(const float32x4_t linear) {
    uint32x4_t mask = vcgtq_f32(linear, vdupq_n_f32(betaRec2020));
    uint32x4_t maskHigh = vcltq_f32(linear, vdupq_n_f32(betaRec2020));

    float32x4_t low = vbslq_f32(mask, vdupq_n_f32(0), linear);
    float32x4_t high = vbslq_f32(maskHigh, vdupq_n_f32(0), linear);

    low = vmulq_n_f32(low, 4.5f);
    constexpr float fk = alphaRec2020 - 1;
    high = vsubq_f32(vmulq_n_f32(vpowq_f32(high, 0.45f), alphaRec2020), vdupq_n_f32(fk));

    return vaddq_f32(low, high);
}

__attribute__((always_inline))
static inline float32x4_t applyMatrixNEON(vector<vector<float>> matrix, const float32x4_t v) {
    const float32x4_t row1 = { matrix[0][0], matrix[0][1], matrix[0][2], 0.0f };
    const float32x4_t row2 = { matrix[1][0], matrix[1][1], matrix[1][2], 0.0f };
    const float32x4_t row3 = { matrix[2][0], matrix[2][1], matrix[2][2], 0.0f };
    const float32x4_t v1 = vmulq_f32(v, row1);
    const float32x4_t v2 = vmulq_f32(v, row2);
    const float32x4_t v3 = vmulq_f32(v, row3);
    const float r = vsumq_f32(v1);
    const float g = vsumq_f32(v2);
    const float b = vsumq_f32(v3);
    const float32x4_t res = { r, g, b, 0.0f };
    return res;
}
#endif

#endif /* Gamma_hpp */
