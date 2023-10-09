//
//  ClampToneMapper.hpp
//  
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
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
    }

    ClampToneMapper(): lumaVec { 0.2126, 0.7152, 0.0722 }, exposure(1.0f), LMax(1.0f) {
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
};

#endif /* ClampToneMapper_hpp */
