//
//  ReinhardToneMapper.hpp
//  
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
//

#ifndef ReinhardToneMapper_hpp
#define ReinhardToneMapper_hpp

#include "ToneMapper.hpp"
#include <stdio.h>
#if __arm64__
#include <arm_neon.h>
#endif
#include <memory>

class ReinhardToneMapper: public ToneMapper {
public:
    ReinhardToneMapper(): lumaVec { 0.2126, 0.7152, 0.0722 }, lumaMaximum(1.0f), exposure(1.2f) {

    }
    ~ReinhardToneMapper() {

    }

    void Execute(float &r, float &g, float &b) override;
#if __arm64__
    float32x4_t Execute(const float32x4_t m) override;
    float32x4x4_t Execute(const float32x4x4_t m) override;
#endif
private:
    float reinhard(const float v);
    const float lumaVec[3] = { 0.2126, 0.7152, 0.0722 };
#if __arm64__
    const float32x4_t vLumaVec = { lumaVec[0], lumaVec[1], lumaVec[2], 0.0f };
#endif
    float Luma(const float r, const float g, const float bs);
    const float lumaMaximum;
    const float exposure;
};

#endif /* ReinhardToneMapper_hpp */
