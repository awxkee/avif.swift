//
//  ClampToneMapper.hpp
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

#ifndef ClampToneMapper_hpp
#define ClampToneMapper_hpp

#include <stdio.h>
#include "ToneMapper.hpp"

#if __arm64__
#include <arm_neon.h>
#endif

class ClampToneMapper: public ToneMapper {
public:
    ClampToneMapper(const float primaries[3]): exposure(1.0f), LMax(1.0f) {
        lumaVec[0] = primaries[0];
        lumaVec[1] = primaries[1];
        lumaVec[2] = primaries[2];
#if __arm64__
        vLumaVec = { lumaVec[0], lumaVec[1], lumaVec[2], 0.0f };
#endif
        Lmax_ = LMax*exposure;
    }

    ClampToneMapper(): lumaVec { 0.2126, 0.7152, 0.0722 }, exposure(1.0f), LMax(1.0f) {
        Lmax_ = LMax*exposure;
    }

    ~ClampToneMapper() {

    }

    void Execute(float &r, float &g, float &b) override;
#if __arm64__
    float32x4_t Execute(const float32x4_t m) override;
    float32x4x4_t Execute(const float32x4x4_t m) override;
#endif
private:
    const float exposure;
    const float LMax;
    float lumaVec[3];
    float Luma(const float r, const float g, const float b);
#if __arm64__
    float32x4_t vLumaVec = { lumaVec[0], lumaVec[1], lumaVec[2], 0.0f };
#endif
    float Lmax_ = LMax*exposure;
};

#endif /* ClampToneMapper_hpp */
