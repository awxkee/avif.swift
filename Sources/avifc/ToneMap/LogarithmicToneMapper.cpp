//
//  LogarithmicToneMapper.cpp
//  
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
//

#include "LogarithmicToneMapper.hpp"
#include <algorithm>
#include "../NEMath.h"

float LogarithmicToneMapper::Luma(const float r, const float g, const float b) {
    return r * lumaVec[0] + g * lumaVec[1] + b * lumaVec[2];
}

void LogarithmicToneMapper::Execute(float& r, float& g, float &b) {
    r *= exposure;
    g *= exposure;
    b *= exposure;
    const float Lmax_ = exposure * LMax;
    const float Lin = Luma(r*exposure, g*exposure, b*exposure);
    const float den = log10(1.0 + curve * Lmax_);
    const float Lout = log10(abs(1.0 + curve * Lin)) / den;
    const float scale = Lout / Lin;
    if (scale == 1) {
        return;
    }
    r *= scale;
    g *= scale;
    b *= scale;
}

#if __arm64__

float32x4_t LogarithmicToneMapper::Execute(const float32x4_t m) {
    const float Lin = vsumq_f32(vmulq_n_f32(vmulq_f32(m, vLumaVec), exposure));
    const float Lout = log10(abs(1.0 + curve * Lin)) / den;
    const float scale = Lout / Lin;
    if (scale == 1) {
        return vmulq_n_f32(m, exposure);
    }
    return vmulq_n_f32(vmulq_n_f32(m, scale), exposure);
}

float32x4x4_t LogarithmicToneMapper::Execute(const float32x4x4_t m) {
    float32x4_t Lin = {
        vsumq_f32(vmulq_n_f32(vmulq_f32(m.val[0], vLumaVec), exposure)),
        vsumq_f32(vmulq_n_f32(vmulq_f32(m.val[1], vLumaVec), exposure)),
        vsumq_f32(vmulq_n_f32(vmulq_f32(m.val[2], vLumaVec), exposure)),
        vsumq_f32(vmulq_n_f32(vmulq_f32(m.val[3], vLumaVec), exposure)),
    };
    Lin = vsetq_if_f32(Lin, 0.0f, 1.0f);
    const float32x4_t Lout = vsetq_if_f32(
                                          vdivq_f32(vlog10q_f32(vabsq_f32(vmlaq_f32(vdupq_n_f32(1.0f), vdupq_n_f32(curve), Lin))), vdupq_n_f32(den)),
                                          0.0f, 1.0f);
    const float32x4_t scale = vdivq_f32(Lout, Lin);
    float32x4x4_t r = {
        vmulq_n_f32(vmulq_n_f32(m.val[0], vgetq_lane_f32(scale, 0)), exposure),
        vmulq_n_f32(vmulq_n_f32(m.val[1], vgetq_lane_f32(scale, 1)), exposure),
        vmulq_n_f32(vmulq_n_f32(m.val[2], vgetq_lane_f32(scale, 2)), exposure),
        vmulq_n_f32(vmulq_n_f32(m.val[3], vgetq_lane_f32(scale, 3)), exposure)
    };
    return r;
}
#endif
