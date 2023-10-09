//
//  Rec2408ToneMapper.cpp
//  
//
//  Created by Radzivon Bartoshyk on 08/10/2023.
//

#include "Rec2408ToneMapper.hpp"
#include <algorithm>
#include "../NEMath.h"

using namespace std;

#if __arm64__

float Rec2408ToneMapper::SDR(float Lin) {
    const float c1 = 107 / 128;
    const float c2 = 2413 / 128;
    const float c3 = 2392 / 128;
    const float m1 = 1305 / 8192;
    const float m2 = 2523 / 32;
    const float v = pow(Lin / 10000, m1);
    return pow((c1 + c2 * v) / (1 + c3 * v), m2);
}

float32x4_t Rec2408ToneMapper::SDR(float32x4_t Lin) {
    const float c1 = 107 / 128;
    const float c2 = 2413 / 128;
    const float c3 = 2392 / 128;
    const float m1 = 1305 / 8192;
    const float m2 = 2523 / 32;
    const float32x4_t v = vpowq_f32(vdivq_f32(Lin, vdupq_n_f32(10000)), m1);
    return vpowq_f32(vdivq_f32(vmlaq_f32(vdupq_n_f32(c1), vdupq_n_f32(c2), v), vmlaq_f32(vdupq_n_f32(1), vdupq_n_f32(c3), v)), m2);
}

float32x4x4_t Rec2408ToneMapper::Execute(const float32x4x4_t m) {
    const float32x4_t Lin = {
        vsumq_f32(vmulq_f32(m.val[0], this->luma)),
        vsumq_f32(vmulq_f32(m.val[1], this->luma)),
        vsumq_f32(vmulq_f32(m.val[2], this->luma)),
        vsumq_f32(vmulq_f32(m.val[3], this->luma)),
    };
    const float32x4_t Lout = vdivq_f32(vmlaq_f32(this->ones, this->aVec, Lin),
                                          vmlaq_f32(this->ones, this->bVec, Lin));

    float32x4x4_t r = {
        vmulq_n_f32(m.val[0], vgetq_lane_f32(Lout, 0)),
        vmulq_n_f32(m.val[1], vgetq_lane_f32(Lout, 1)),
        vmulq_n_f32(m.val[2], vgetq_lane_f32(Lout, 2)),
        vmulq_n_f32(m.val[3], vgetq_lane_f32(Lout, 3))
    };
    
    return r;
}

float32x4_t Rec2408ToneMapper::Execute(const float32x4_t m) {
    const float Lin = vsumq_f32(vmulq_f32(m, this->luma));
    if (Lin == 0) {
        return m;
    }
    const float shScale = (1.f + this->a * Lin) / (1.f + this->b * Lin);
    return vmulq_n_f32(m, shScale);
}

#endif

void Rec2408ToneMapper::Execute(float& r, float &g, float& b) {
    const float Lin = r*0.2627 + g*0.6780 + b * 0.0593;
    if (Lin == 0) {
        return;;
    }
    const float shScale = (1.f + this->a * Lin) / (1.f + this->b * Lin);
    r = r * shScale;
    g = g * shScale;
    b = b * shScale;
}
