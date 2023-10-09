//
//  LogarithmicToneMapper.hpp
//  
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
//

#ifndef LogarithmicToneMapper_hpp
#define LogarithmicToneMapper_hpp

#include <stdio.h>
#include "ToneMapper.hpp"

#if __arm64__
#include <arm_neon.h>
#endif

class LogarithmicToneMapper: public ToneMapper {
public:
    LogarithmicToneMapper(): lumaVec { 0.2126, 0.7152, 0.0722 }, curve(1.0f), exposure(1.5f), LMax(1.0f) {

    }

    ~LogarithmicToneMapper() {

    }

    void Execute(float &r, float &g, float &b) override;
#if __arm64__
    float32x4_t Execute(const float32x4_t m) override;
    float32x4x4_t Execute(const float32x4x4_t m) override;
#endif
private:
    const float exposure;
    const float LMax;
    const float lumaVec[3] = { 0.2126, 0.7152, 0.0722 };
    const float curve;
    float Luma(const float r, const float g, const float b);
#if __arm64__
    const float32x4_t vLumaVec = { lumaVec[0], lumaVec[1], lumaVec[2], 0.0f };
#endif
};

#endif /* LogarithmicToneMapper_hpp */
