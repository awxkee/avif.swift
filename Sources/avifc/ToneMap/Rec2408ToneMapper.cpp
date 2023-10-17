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

float32x4x4_t Rec2408ToneMapper::Execute(const float32x4x4_t m) {
    const float32x4_t lc = luma;
    const float32x4_t Lin = {
        vdot_f32(m.val[0], lc),
        vdot_f32(m.val[1], lc),
        vdot_f32(m.val[2], lc),
        vdot_f32(m.val[3], lc),
    };
    const float32x4_t ones = vdupq_n_f32(1.f);
    const float32x4_t Lout = vmulq_f32(vmlaq_n_f32(ones, Lin, this->a),
                                       vrecpeq_f32(vmlaq_n_f32(ones, Lin, this->b)));
    float32x4x4_t r = {
        vmulq_laneq_f32(m.val[0], Lout, 0),
        vmulq_laneq_f32(m.val[1], Lout, 1),
        vmulq_laneq_f32(m.val[2], Lout, 2),
        vmulq_laneq_f32(m.val[3], Lout, 3)
    };

    return r;
}

float32x4_t Rec2408ToneMapper::Execute(const float32x4_t m) {
    const float Lin = vaddvq_f32(vmulq_f32(m, this->luma));
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
