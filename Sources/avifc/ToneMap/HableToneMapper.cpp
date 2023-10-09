//
//  HableToneMapper.cpp
//  
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
//

#include "HableToneMapper.hpp"

float HableToneMapper::hable(const float x)
{
    const float A = 0.15, B = 0.50, C = 0.10, D = 0.20, E = 0.02, F = 0.30;
    return ((x * (A * x + (C * B)) + (D * E)) / (x * (A * x + B) + (D * F))) - E / F;
}

void HableToneMapper::Execute(float& r, float& g, float &b) {
    r = hable(r) / sig;
    g = hable(g) / sig;
    b = hable(b) / sig;
}

#if __arm64__
float32x4_t HableToneMapper::Execute(const float32x4_t m) {
    const float A = 0.15, B = 0.50, C = 0.10, D = 0.20, E = 0.02, F = 0.30;
    const float32x4_t v = vmulq_n_f32(m, exposure);
    const float32x4_t den = vaddq_f32(vmulq_f32(v, vaddq_f32(vmulq_n_f32(v, A), vdupq_n_f32(C*B))), vdupq_n_f32(D*E));
    const float32x4_t num = vaddq_f32(vmulq_f32(vmlaq_f32(vdupq_n_f32(B), v, vdupq_n_f32(A)), v), vdupq_n_f32(D*F));
    return vdivq_f32(vsubq_f32(vdivq_f32(den, num), vdupq_n_f32(E/F)), sigVec);
}

float32x4x4_t HableToneMapper::Execute(const float32x4x4_t m) {
    float32x4x4_t r = {
        this->Execute(m.val[0]),
        this->Execute(m.val[1]),
        this->Execute(m.val[2]),
        this->Execute(m.val[3]),
    };
    return r;
}
#endif
