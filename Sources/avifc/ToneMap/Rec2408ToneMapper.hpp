//
//  Rec2408ToneMapper.hpp
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

#ifndef Rec2408ToneMapper_hpp
#define Rec2408ToneMapper_hpp

#include "ToneMapper.hpp"

#include <stdio.h>
#include <memory>

#if __arm64__
#include <arm_neon.h>
#endif

class Rec2408ToneMapper: public ToneMapper {
public:
    Rec2408ToneMapper(const float contentMaxBrightness,
                      const float displayMaxBrightness,
                      const float whitePoint,
                      const float lumaCoefficients[3]): ToneMapper() {
        this->Ld = contentMaxBrightness / whitePoint;
        this->a = (displayMaxBrightness/whitePoint) / (Ld*Ld);
        this->b = 1.0f / (displayMaxBrightness/whitePoint);
        memcpy(this->lumaCoefficients, lumaCoefficients, sizeof(float)*3);
#if __arm64__
        this->aVec = vdupq_n_f32(a);
        this->bVec = vdupq_n_f32(b);
        this->ones = vdupq_n_f32(1.f);
        this->luma = { lumaCoefficients[0], lumaCoefficients[1], lumaCoefficients[2], 0.0f };
#endif
    }

    void Execute(float &r, float &g, float &b) override;
#if __arm64__
    float32x4_t Execute(const float32x4_t m) override;
    float32x4x4_t Execute(const float32x4x4_t m) override;
#endif

private:
    float Ld;
    float a;
    float b;
    float SDR(float Lin);
    float lumaCoefficients[3];
#if __arm64__
    float32x4_t SDR(float32x4_t Lin);
    float32x4_t aVec;
    float32x4_t bVec;
    float32x4_t ones;
    float32x4_t luma;
#endif
};

#endif /* Rec2408ToneMapper_hpp */
