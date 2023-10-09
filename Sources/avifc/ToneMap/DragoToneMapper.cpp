//
//  DragoToneMapper.cpp
//  
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
//

#include "DragoToneMapper.hpp"
#include <algorithm>

using namespace std;

float DragoToneMapper::Luma(const float r, const float g, const float b) {
    return r * lumaVec[0] + g * lumaVec[1] + b * lumaVec[2];
}

void DragoToneMapper::Execute(float& r, float& g, float &b) {
    float Lin = Luma(r * exposure, g * exposure, b * exposure);

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

    r = r * exposure * scale;
    g = g * exposure * scale;
    b = b * exposure * scale;
}

#if __arm64__

__attribute__((always_inline))
static inline float vsumq_f32Drago(const float32x4_t v) {
    float32x2_t r = vadd_f32(vget_high_f32(v), vget_low_f32(v));
    return vget_lane_f32(vpadd_f32(r, r), 0);
}

float32x4_t DragoToneMapper::Execute(const float32x4_t m) {
    const float Lin = vsumq_f32Drago(vmulq_n_f32(vmulq_f32(m, vLumaVec), exposure));
    if (Lin == 0) {
        return m;
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
        return m;
    }
    return vmulq_n_f32(m, scale*exposure);
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
