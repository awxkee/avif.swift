//
//  ReinhardToneMapper.cpp
//  
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
//

#include "ReinhardToneMapper.hpp"

float ReinhardToneMapper::Luma(const float r, const float g, const float b) {
    return r * lumaVec[0] + g * lumaVec[1] + b * lumaVec[2];
}

float ReinhardToneMapper::reinhard(const float v) {
    float Ld = (exposure * v * (1 + (v / (lumaMaximum * lumaMaximum)))) / (1 + exposure * v);
    return Ld;
//    return v / (1.0f + v);
}

void ReinhardToneMapper::Execute(float& r, float& g, float& b) {
    const float luma = Luma(r, g, b);
    if (luma == 0) {
        return;
    }
    const float reinhardLuma = reinhard(luma);
    const float scale = reinhardLuma / luma;

    r = r * scale;
    g = g * scale;
    b = b * scale;
}

#if __arm64__

__attribute__((always_inline))
static inline float vsumq_f32R(const float32x4_t v) {
    float32x2_t r = vadd_f32(vget_high_f32(v), vget_low_f32(v));
    return vget_lane_f32(vpadd_f32(r, r), 0);
}

float32x4_t ReinhardToneMapper::Execute(const float32x4_t m) {
    const float luma = vsumq_f32R(vmulq_f32(m, vLumaVec));
    if (luma == 0) {
        return m;
    }
    const float reinhardLuma = reinhard(luma);
    const float scale = reinhardLuma / luma;
    return vmulq_n_f32(m, scale);
}

float32x4x4_t ReinhardToneMapper::Execute(const float32x4x4_t m) {
    float32x4x4_t r = {
        this->Execute(m.val[0]),
        this->Execute(m.val[1]),
        this->Execute(m.val[2]),
        this->Execute(m.val[3]),
    };
    return r;
}
#endif
