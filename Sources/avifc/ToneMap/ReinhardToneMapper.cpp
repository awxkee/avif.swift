//
//  ReinhardToneMapper.cpp
//
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
//

#include "ReinhardToneMapper.hpp"
#include "../NEMath.h"

#if defined(__clang__)
#pragma clang fp contract(fast) exceptions(ignore) reassociate(on)
#endif

#if __arm64__
__attribute__((always_inline))
inline float32x4_t reinhardNEON(const float32x4_t v, const float lumaMaximum, const bool useExtended) {
    if (useExtended) {
        return vdivq_f32(vmulq_f32(v, vaddq_f32(vdupq_n_f32(1), vdivq_f32(v, vdupq_n_f32(lumaMaximum * lumaMaximum)))),
                         vaddq_f32(vdupq_n_f32(1.0f), v));
    }
    return vdivq_f32(v, vaddq_f32(vdupq_n_f32(1.0f), v));
}
#endif

float ReinhardToneMapper::Luma(const float r, const float g, const float b) {
    return r * lumaVec[0] + g * lumaVec[1] + b * lumaVec[2];
}

float ReinhardToneMapper::reinhard(const float v) {
    if (useExtended) {
        float Ld = (v * (1 + (v / (lumaMaximum * lumaMaximum)))) / (1 + v);
        return Ld;
    }
    return v / (1.0f + v);
}

void ReinhardToneMapper::Execute(float& r, float& g, float& b) {
    r *= exposure;
    g *= exposure;
    b *= exposure;
    const float luma = Luma(r, g, b);
    if (luma == 0) {
        return;
    }
    const float reinhardLuma = reinhard(luma);
    const float scale = reinhardLuma / luma;
    if (scale == 1) {
        return;
    }
    r = r * scale;
    g = g * scale;
    b = b * scale;
}

#if __arm64__

float32x4_t ReinhardToneMapper::Execute(const float32x4_t m) {
    const float32x4_t v = vmulq_n_f32(m, exposure);
    const float luma = vsumq_f32(vmulq_f32(v, vLumaVec));
    if (luma == 0) {
        return m;
    }
    const float reinhardLuma = reinhard(luma);
    const float scale = reinhardLuma / luma;
    if (scale == 1) {
        return v;
    }
    return vmulq_n_f32(m, scale);
}

float32x4x4_t ReinhardToneMapper::Execute(const float32x4x4_t m) {
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
    const float32x4_t Lout = vsetq_if_f32(reinhardNEON(Lin, lumaMaximum, useExtended), 0.0f, 1.0f);
    const float32x4_t scale = vdivq_f32(Lout, Lin);
    float32x4x4_t r = {
        vmulq_n_f32(exposured.val[0], vgetq_lane_f32(scale, 0)),
        vmulq_n_f32(exposured.val[1], vgetq_lane_f32(scale, 1)),
        vmulq_n_f32(exposured.val[2], vgetq_lane_f32(scale, 2)),
        vmulq_n_f32(exposured.val[3], vgetq_lane_f32(scale, 3)),
    };
    return r;
}
#endif
