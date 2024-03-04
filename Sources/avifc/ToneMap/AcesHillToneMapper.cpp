//
//  AcesHillToneMapper.cpp
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
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

#include "AcesHillToneMapper.hpp"

float AcesCurve(const float Cin) {
    const float a    = Cin * (Cin + 0.0245786f) - 0.000090537f;
    const float b    = Cin * (0.983729f * Cin + 0.4329510f) + 0.238081f;
    const float Cout = a / b;
    return Cout;
}

void AcesHillToneMapper::Execute(float& r, float& g, float& b) {
    auto mulInput = [](float& r, float& g, float& b) {
        float a1 = 0.59719f * r + 0.35458f * g + 0.04823f * b,
        b1 = 0.07600f * r + 0.90834f * g + 0.01566f * b,
        c1 = 0.02840f * r + 0.13383f * g + 0.83777f * b;
        r = a1;
        g = b1;
        b = c1;
    };

    auto mulOutput = [](float& r, float& g, float& b) {
        float a1 =  1.60475f * r - 0.53108f * g - 0.07367f * b,
        b1 = -0.10208f * r + 1.10813f * g - 0.00605f * b,
        c1 = -0.00327f * r - 0.07276f * g + 1.07602f * b;
        r = a1;
        g = b1;
        b = c1;
    };

    // Fetch color
    r = r*exposure;
    g = g*exposure;
    b = b*exposure;

    // Apply curve directly on color input
    mulInput(r,g, b);
    r = AcesCurve(r);
    g = AcesCurve(g);
    b = AcesCurve(b);
    mulOutput(r, g, b);
}

#if __arm64__

__attribute__((flatten))
static inline float vsumq_f32A(const float32x4_t v) {
    float32x2_t r = vadd_f32(vget_high_f32(v), vget_low_f32(v));
    return vget_lane_f32(vpadd_f32(r, r), 0);
}

inline float32x4_t AcesInputMul(const float32x4_t m) {
    const float32x4_t row1 = { 0.59719f, 0.35458f, 0.04823f, 0.0f };
    const float32x4_t row2 = { 0.07600f, 0.90834f, 0.01566f, 0.0f };
    const float32x4_t row3 = { 0.02840f, 0.13383f, 0.83777f, 0.0f };
    const float rNew = vsumq_f32A(vmulq_f32(m, row1));
    const float gNew = vsumq_f32A(vmulq_f32(m, row2));
    const float bNew = vsumq_f32A(vmulq_f32(m, row3));
    float32x4_t v = { rNew, gNew, bNew };
    return v;
}

inline float32x4_t AcesOutputMul(const float32x4_t m) {
    const float32x4_t row1 = { 1.60475f, -0.53108f, -0.07367f, 0.0f };
    const float32x4_t row2 = { -0.10208f, 1.10813f, -0.00605f, 0.0f };
    const float32x4_t row3 = { -0.00327f, -0.07276f, 1.07602f, 0.0f };
    const float rNew = vsumq_f32A(vmulq_f32(m, row1));
    const float gNew = vsumq_f32A(vmulq_f32(m, row2));
    const float bNew = vsumq_f32A(vmulq_f32(m, row3));
    float32x4_t v = { rNew, gNew, bNew };
    return v;
}

inline float32x4_t AcesCurve(const float32x4_t Cin) {
    const float32x4_t a = vsubq_f32(vmulq_f32(vaddq_f32(Cin, vdupq_n_f32(0.0245786f)), Cin), vdupq_n_f32(0.000090537f));
    const float32x4_t b = vmlaq_f32(vdupq_n_f32(0.238081f), vmlaq_f32(vdupq_n_f32(0.4329510f), Cin, vdupq_n_f32(0.983729f)), Cin);
    float32x4_t Cout = vdivq_f32(a, b);
    return Cout;
}

float32x4_t AcesHillToneMapper::Execute(const float32x4_t m) {
    float32x4_t vm = vmulq_n_f32(AcesInputMul(m), exposure);
    vm = AcesCurve(vm);
    return AcesOutputMul(vm);
}

float32x4x4_t AcesHillToneMapper::Execute(const float32x4x4_t m) {
    float32x4x4_t r = {
        this->Execute(m.val[0]),
        this->Execute(m.val[1]),
        this->Execute(m.val[2]),
        this->Execute(m.val[3]),
    };
    return r;
}
#endif
