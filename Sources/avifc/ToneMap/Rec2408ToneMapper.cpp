//
//  Rec2408ToneMapper.cpp
//  
//
//  Created by Radzivon Bartoshyk on 08/10/2023.
//

#include "Rec2408ToneMapper.hpp"
#include <algorithm>

using namespace std;

#if __arm64__

__attribute__((always_inline))
inline float vsumq_f32(const float32x4_t v) {
    float32x2_t r = vadd_f32(vget_high_f32(v), vget_low_f32(v));
    return vget_lane_f32(vpadd_f32(r, r), 0);
}

float32x4x4_t Rec2408ToneMapper::Execute(const float32x4x4_t m) {
    const float32x4_t maximum = {
        vsumq_f32(vmulq_f32(m.val[0], this->luma)),
        vsumq_f32(vmulq_f32(m.val[1], this->luma)),
        vsumq_f32(vmulq_f32(m.val[2], this->luma)),
        vsumq_f32(vmulq_f32(m.val[3], this->luma)),
    };
    const float32x4_t shScale = vdivq_f32(vmlaq_f32(this->ones, this->aVec, maximum),
                                          vmlaq_f32(this->ones, this->bVec, maximum));
    float32x4x4_t r = {
        vmulq_n_f32(m.val[0], vgetq_lane_f32(shScale, 0)),
        vmulq_n_f32(m.val[1], vgetq_lane_f32(shScale, 1)),
        vmulq_n_f32(m.val[2], vgetq_lane_f32(shScale, 2)),
        vmulq_n_f32(m.val[3], vgetq_lane_f32(shScale, 3))
    };
    return r;
}

float32x4_t Rec2408ToneMapper::Execute(const float32x4_t m) {
    const float maximum = vsumq_f32(vmulq_f32(m, this->luma));
    const float shScale = (1.f + this->a * maximum) / (1.f + this->b * maximum);
    return vmulq_n_f32(m, shScale);
}

#endif

void Rec2408ToneMapper::Execute(float& r, float &g, float& b) {
    const float maximum = r*0.2627 + g*0.6780 + b * 0.0593;
    if (maximum > 0) {
        const float shScale = (1.f + this->a * maximum) / (1.f + this->b * maximum);
        r = r * shScale;
        g = g * shScale;
        b = b * shScale;
    }
}
