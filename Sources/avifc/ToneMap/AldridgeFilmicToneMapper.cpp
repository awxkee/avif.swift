//
//  AldridgeFilmicToneMapper.cpp
//
//
//  Created by Radzivon Bartoshyk on 10/10/2023.
//

#include "AldridgeFilmicToneMapper.hpp"
#include <algorithm>

using namespace std;

#if defined(__clang__)
#pragma clang fp contract(fast) exceptions(ignore) reassociate(on)
#endif

float AldridgeFilmicToneMapper::aldridge(const float v, const float exposure) {
    const float Cin = exposure * v;

    // Apply curve directly on color input
    const float tmp  = float(2.f * cutoff);
    const float x    = Cin + (tmp - Cin) * clamp(tmp - Cin, 0.f, 1.f) * (0.25f / cutoff) - cutoff;
    const float Cout = (x * (6.2f * x + 0.5f)) / (x * (6.2f * x + 1.7f) + 0.06f);
    return pow(Cout, 2.4f);
}

void AldridgeFilmicToneMapper::Execute(float& r, float& g, float &b) {
    r = aldridge(r, exposure);
    g = aldridge(g, exposure);
    b = aldridge(b, exposure);
}

#if __arm64__
float32x4_t AldridgeFilmicToneMapper::Execute(const float32x4_t m) {
    float r = vgetq_lane_f32(m, 0);
    float g = vgetq_lane_f32(m, 1);
    float b = vgetq_lane_f32(m, 2);
    Execute(r, g, b);
    const float32x4_t v = {
        r, g, b, 0.0f
    };
    return v;
}

float32x4x4_t AldridgeFilmicToneMapper::Execute(const float32x4x4_t m) {
    float32x4x4_t r = {
        this->Execute(m.val[0]),
        this->Execute(m.val[1]),
        this->Execute(m.val[2]),
        this->Execute(m.val[3]),
    };
    return r;
}
#endif
