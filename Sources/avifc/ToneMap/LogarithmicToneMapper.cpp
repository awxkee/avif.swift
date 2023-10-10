//
//  LogarithmicToneMapper.cpp
//  
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
//

#include "LogarithmicToneMapper.hpp"
#include <algorithm>
#include "../NEMath.h"
#include "../Math/math_log10f.hpp"
#include "../Math/math_fabs.hpp"

#if defined(__clang__)
#pragma clang fp contract(fast) exceptions(ignore) reassociate(on)
#endif

float LogarithmicToneMapper::Luma(const float r, const float g, const float b) {
    return r * lumaVec[0] + g * lumaVec[1] + b * lumaVec[2];
}

void LogarithmicToneMapper::Execute(float& r, float& g, float &b) {
    r *= exposure;
    g *= exposure;
    b *= exposure;
    const float Lin = Luma(r, g, b);
#if __arm64__
    const float Lout = vgetq_lane_f32(vdivq_f32(vlog10q_f32(vdupq_n_f32(fabsf_c(1.0 + curve * Lin))), vDenVec), 0);
#else
    const float Lout = log10f_c(abs(1.0 + curve * Lin)) / den;
#endif
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
    const float32x4_t v = vmulq_n_f32(m, exposure);
    const float Lin = vsumq_f32(vmulq_f32(v, vLumaVec));
    const float Lout = vgetq_lane_f32(vdivq_f32(vlog10q_f32(vdupq_n_f32(fabsf_c(1.0 + curve * Lin))), vDenVec), 0);
    const float scale = Lout / Lin;
    if (scale == 1) {
        return v;
    }
    return vmulq_n_f32(v, scale);
}

float32x4x4_t LogarithmicToneMapper::Execute(const float32x4x4_t m) {
    float32x4x4_t exposured = {
        vmulq_n_f32(m.val[0], exposure),
        vmulq_n_f32(m.val[1], exposure),
        vmulq_n_f32(m.val[2], exposure),
        vmulq_n_f32(m.val[3], exposure),
    };
    float32x4_t Lin = {
        vsumq_f32(vmulq_f32(exposured.val[0], vLumaVec)),
        vsumq_f32(vmulq_f32(exposured.val[1], vLumaVec)),
        vsumq_f32(vmulq_f32(exposured.val[2], vLumaVec)),
        vsumq_f32(vmulq_f32(exposured.val[3], vLumaVec)),
    };
    Lin = vsetq_if_f32(Lin, 0.0f, 1.0f);
    const float32x4_t Lout = vsetq_if_f32(
                                          vdivq_f32(vlog10q_f32(vabsq_f32(vmlaq_f32(vdupq_n_f32(1.0f), vdupq_n_f32(curve), Lin))), vDenVec),
                                          0.0f, 1.0f);
    const float32x4_t scale = vdivq_f32(Lout, Lin);
    float32x4x4_t r = {
        vmulq_n_f32(exposured.val[0], vgetq_lane_f32(scale, 0)),
        vmulq_n_f32(exposured.val[1], vgetq_lane_f32(scale, 1)),
        vmulq_n_f32(exposured.val[2], vgetq_lane_f32(scale, 2)),
        vmulq_n_f32(exposured.val[3], vgetq_lane_f32(scale, 3))
    };
    return r;
}
#endif
