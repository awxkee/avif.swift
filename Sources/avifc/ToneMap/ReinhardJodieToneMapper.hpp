//
//  ReinhardJodieToneMapper.hpp
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

#ifndef ReinhardJodieToneMapper_hpp
#define ReinhardJodieToneMapper_hpp

#include "ToneMapper.hpp"
#include <stdio.h>
#if __arm64__
#include <arm_neon.h>
#endif

class ReinhardJodieToneMapper: public ToneMapper {
public:
    ReinhardJodieToneMapper(const bool extended = true): lumaVec { 0.2126, 0.7152, 0.0722 }, lumaMaximum(1.0f), exposure(1.2f) {
        useExtended = extended;
#if __arm64__
        vLumaVec = { lumaVec[0], lumaVec[1], lumaVec[2], 0.0f };
#endif
    }

    ReinhardJodieToneMapper(const float primaries[3], const bool extended = true): lumaMaximum(1.0f), exposure(1.0f) {
        lumaVec[0] = primaries[0];
        lumaVec[1] = primaries[1];
        lumaVec[2] = primaries[2];
#if __arm64__
        vLumaVec = { lumaVec[0], lumaVec[1], lumaVec[2], 0.0f };
#endif
        useExtended = extended;
    }

    ~ReinhardJodieToneMapper() {

    }

    void Execute(float &r, float &g, float &b) override;
#if __arm64__
    float32x4_t Execute(const float32x4_t m) override;
    float32x4x4_t Execute(const float32x4x4_t m) override;
#endif
private:
    float reinhard(const float v);
    float lumaVec[3] = { 0.2126, 0.7152, 0.0722 };
#if __arm64__
    float32x4_t vLumaVec = { lumaVec[0], lumaVec[1], lumaVec[2], 0.0f };
#endif
    float Luma(const float r, const float g, const float bs);
    const float lumaMaximum;
    const float exposure;
    bool useExtended;
};

#endif /* ReinhardJodieToneMapper_hpp */
