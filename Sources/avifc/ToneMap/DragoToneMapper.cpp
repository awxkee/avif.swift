//
//  DragoToneMapper.cpp
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

#include "DragoToneMapper.hpp"
#include <algorithm>

using namespace std;

#if defined(__clang__)
#pragma clang fp contract(fast) exceptions(ignore) reassociate(on)
#endif

float DragoToneMapper::Luma(const float r, const float g, const float b) {
    return r * lumaVec[0] + g * lumaVec[1] + b * lumaVec[2];
}

void DragoToneMapper::Execute(float& r, float& g, float &b) {
    r *= exposure;
    g *= exposure;
    b *= exposure;
    float Lin = Luma(r, g, b);

    // Apply exposure scale to parameters
    const float Lmax = this->LdMax * exposure;

    // Bias the world adaptation and scale other parameters accordingly
    float LwaP  = Lwa / pow(1.f + b - 0.85f, 5.f),
          LmaxP = Lmax / LwaP,
          LinP  = Lin / LwaP;

    // Apply tonemapping curve to luminance
    float exponent = std::log(b) / std::log(0.5f),
          c1       = (0.01f * LdMax) / std::log10(1.f + LmaxP),
          c2       = log(1.f + LinP) / std::log(2.f + 8.f * pow(LinP / LmaxP, exponent)),
          Lout     = c1 * c2;

    const float scale = Lout / Lin;
    if (scale == 1) {
        return;
    }

    r = r * scale;
    g = g * scale;
    b = b * scale;
}

#if __arm64__

float32x4_t DragoToneMapper::Execute(const float32x4_t m) {
    const float32x4_t v = vmulq_n_f32(m, exposure);
    const float Lin = vaddvq_f32(vmulq_n_f32(vmulq_f32(v, vLumaVec), exposure));
    if (Lin == 0) {
        return v;
    }
    const float Lmax = this->LdMax * exposure;

    // Bias the world adaptation and scale other parameters accordingly
    float LwaP  = Lwa / pow(1.f + b - 0.85f, 5.f),
          LmaxP = Lmax / LwaP,
          LinP  = Lin / LwaP;

    // Apply tonemapping curve to luminance
    float exponent = log(b) / log(0.5f),
          c1       = (0.01f * LdMax) / log10(1.f + LmaxP),
          c2       = log(1.f + LinP) / log(2.f + 8.f * pow(LinP / LmaxP, exponent)),
          Lout     = c1 * c2;

    const float scale = Lout / Lin;
    if (scale == 1) {
        return v;
    }
    return vmulq_n_f32(m, scale);
}

float32x4x4_t DragoToneMapper::Execute(const float32x4x4_t m) {
    float32x4x4_t r = {
        this->Execute(m.val[0]),
        this->Execute(m.val[1]),
        this->Execute(m.val[2]),
        this->Execute(m.val[3]),
    };
    return r;
}
#endif
