//
//  LogarithmicToneMapper.cpp
//  
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
//

#include "LogarithmicToneMapper.hpp"
#include <algorithm>

float LogarithmicToneMapper::Luma(const float r, const float g, const float b) {
    return r * lumaVec[0] + g * lumaVec[1] + b * lumaVec[2];
}

void LogarithmicToneMapper::Execute(float& r, float& g, float &b) {
    const float Lmax_ = exposure * LMax;
    const float Lin = Luma(r, g, b);
    float Lout = log10(1.0 + curve * Lin) / log10(1.0 + curve * Lmax_);
}

#if __arm64__

__attribute__((always_inline))
static inline float vsumq_f32LG(const float32x4_t v) {
    float32x2_t r = vadd_f32(vget_high_f32(v), vget_low_f32(v));
    return vget_lane_f32(vpadd_f32(r, r), 0);
}

float32x4_t LogarithmicToneMapper::Execute(const float32x4_t m) {
    const float Lmax_ = exposure * LMax;
    const float Lin = vsumq_f32LG(vmulq_f32(m, vLumaVec));
    const float Lout = log10(1.0 + curve * Lin) / log10(1.0 + curve * Lmax_);
    const float scale = Lout / Lin;
    return vmulq_n_f32(m, scale);
}

float32x4x4_t LogarithmicToneMapper::Execute(const float32x4x4_t m) {
    float32x4x4_t r = {
        this->Execute(m.val[0]),
        this->Execute(m.val[1]),
        this->Execute(m.val[2]),
        this->Execute(m.val[3]),
    };
    return r;
}
#endif
