//
//  Rec2408ToneMapper.cpp
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 08/10/2023.
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

#include "Rec2408ToneMapper.hpp"
#include <algorithm>
#include "NEMath.h"

using namespace std;

#if __arm64__

float Rec2408ToneMapper::SDR(float Lin) {
    const float c1 = 107 / 128;
    const float c2 = 2413 / 128;
    const float c3 = 2392 / 128;
    const float m1 = 1305 / 8192;
    const float m2 = 2523 / 32;
    const float v = pow(Lin / 10000, m1);
    return pow((c1 + c2 * v) / (1 + c3 * v), m2);
}

float32x4_t Rec2408ToneMapper::SDR(float32x4_t Lin) {
    const float c1 = 107 / 128;
    const float c2 = 2413 / 128;
    const float c3 = 2392 / 128;
    const float m1 = 1305 / 8192;
    const float m2 = 2523 / 32;
    const float32x4_t v = vpowq_f32(vdivq_f32(Lin, vdupq_n_f32(10000)), m1);
    return vpowq_f32(vdivq_f32(vmlaq_f32(vdupq_n_f32(c1), vdupq_n_f32(c2), v), vmlaq_f32(vdupq_n_f32(1), vdupq_n_f32(c3), v)), m2);
}

float32x4x4_t Rec2408ToneMapper::Execute(const float32x4x4_t m) {
    const float32x4x4_t lumas = {
        vmulq_f32(m.val[0], luma),
        vmulq_f32(m.val[1], luma),
        vmulq_f32(m.val[2], luma),
        vmulq_f32(m.val[3], luma),
    };
    const float32x4_t Lin = vsumq_f32x4(lumas.val[0], lumas.val[1], lumas.val[2], lumas.val[3]);
    const float32x4_t Lout = vdivq_f32(vmlaq_f32(this->ones, this->aVec, Lin),
                                          vmlaq_f32(this->ones, this->bVec, Lin));

    float32x4x4_t r = {
        vmulq_n_f32(m.val[0], vgetq_lane_f32(Lout, 0)),
        vmulq_n_f32(m.val[1], vgetq_lane_f32(Lout, 1)),
        vmulq_n_f32(m.val[2], vgetq_lane_f32(Lout, 2)),
        vmulq_n_f32(m.val[3], vgetq_lane_f32(Lout, 3))
    };
    
    return r;
}

float32x4_t Rec2408ToneMapper::Execute(const float32x4_t m) {
    const float Lin = vsumq_f32(vmulq_f32(m, this->luma));
    if (Lin == 0) {
        return m;
    }
    const float shScale = (1.f + this->a * Lin) / (1.f + this->b * Lin);
    return vmulq_n_f32(m, shScale);
}

#endif

void Rec2408ToneMapper::Execute(float& r, float &g, float& b) {
    const float Lin = r*lumaCoefficients[0] + g*lumaCoefficients[1] + b * lumaCoefficients[2];
    if (Lin == 0) {
        return;
    }
    const float shScale = (1.f + this->a * Lin) / (1.f + this->b * Lin);
    r = r * shScale;
    g = g * shScale;
    b = b * shScale;
}
