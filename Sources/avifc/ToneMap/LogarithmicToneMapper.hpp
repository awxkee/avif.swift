//
//  LogarithmicToneMapper.hpp
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

#ifndef LogarithmicToneMapper_hpp
#define LogarithmicToneMapper_hpp

#include <stdio.h>
#include "ToneMapper.hpp"
#include <algorithm>

using namespace std;

#if __arm64__
#include <arm_neon.h>
#endif

class LogarithmicToneMapper: public ToneMapper {
public:

    LogarithmicToneMapper(const float primaries[3]): curve(1.0f), exposure(1.0f), LMax(1.0f) {
        lumaVec[0] = primaries[0];
        lumaVec[1] = primaries[1];
        lumaVec[2] = primaries[2];
        Lmax_ = exposure * LMax;
        den = log10(1.0 + curve * Lmax_);
#if __arm64__
        vLumaVec = { lumaVec[0], lumaVec[1], lumaVec[2], 0.0f };
        vDenVec = vdupq_n_f32(1.0f /den);
#endif
    }

    LogarithmicToneMapper(): lumaVec { 0.2126, 0.7152, 0.0722 }, curve(1.0f), exposure(1.0f), LMax(1.0f) {
        Lmax_ = exposure * LMax;
        den = log10(1.0 + curve * Lmax_);
#if __arm64__
        vLumaVec = { lumaVec[0], lumaVec[1], lumaVec[2], 0.0f };
        vDenVec = vdupq_n_f32(1.0f / den);
#endif
    }

    ~LogarithmicToneMapper() {

    }

    void Execute(float &r, float &g, float &b) override;
#if __arm64__
    float32x4_t Execute(const float32x4_t m) override;
    float32x4x4_t Execute(const float32x4x4_t m) override;
#endif
private:
    float Lmax_ = exposure * LMax;
    float den = log10(1.0 + curve * Lmax_);
    const float exposure;
    const float LMax;
    float lumaVec[3] = { 0.2126, 0.7152, 0.0722 };
    const float curve;
    float Luma(const float r, const float g, const float b);
#if __arm64__
    float32x4_t vLumaVec = { lumaVec[0], lumaVec[1], lumaVec[2], 0.0f };
    float32x4_t vDenVec;
#endif
};

#endif /* LogarithmicToneMapper_hpp */
