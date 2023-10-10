//
//  UchimuraToneMapper.cpp
//
//
//  Created by Radzivon Bartoshyk on 10/10/2023.
//

#include "UchimuraToneMapper.hpp"
#include <algorithm>

using namespace std;

#if defined(__clang__)
#pragma clang fp contract(fast) exceptions(ignore) reassociate(on)
#endif

template <typename T>
inline T smoothstep(T edge0, T edge1, T x) {
    // https://docs.gl/sl4/smoothstep
    T t = clamp((x - edge0) / (edge1 - edge0), T(0), T(1));
    return t * t * (T(3) - T(2) * t);
}

template <typename T>
inline T step(T edge, T x) {
    // https://docs.gl/sl4/step
    return smoothstep(edge, edge, x);
}

float UchimuraToneMapper::uchimura(const float v, const float exposure) {
    float P = 1,
    a = 1,
    m = 0.22f,
    l = 0.4f,
    c = 1.33f,
    b = 0;

    // Fetch color
    float Cin = exposure * v;

    // Apply curve directly on color input
    float l0 = ((P - m) * l) / a,
    S0 = m + l0,
    S1 = m + a * l0,
    C2 = (a * P) / (P - S1),
    CP = -C2 / P;

    float w0 = (1.f) - smoothstep(float(0.f), float(m), Cin),
    w2 = step(float(m + l0), Cin),
    w1 = float(1.f) - w0 - w2;

    float T = m * pow(Cin / m, c) + b,                       // toe
    L = float(m) + a * (Cin - float(m)),           // linear
    S = float(P) - (P - S1) * exp(CP * (Cin - S0));  // shoulder

    float Cout = T * w0 + L * w1 + S * w2;
    return Cout;
}

void UchimuraToneMapper::Execute(float& r, float& g, float &b) {
    r = uchimura(r, exposure);
    g = uchimura(g, exposure);
    b = uchimura(b, exposure);
}

#if __arm64__

float32x4_t UchimuraToneMapper::Execute(const float32x4_t m) {
    float r = vgetq_lane_f32(m, 0);
    float g = vgetq_lane_f32(m, 1);
    float b = vgetq_lane_f32(m, 2);
    Execute(r, g, b);
    const float32x4_t v = {
        r, g, b, 0.0f
    };
    return v;
}

float32x4x4_t UchimuraToneMapper::Execute(const float32x4x4_t m) {
    float32x4x4_t r = {
        this->Execute(m.val[0]),
        this->Execute(m.val[1]),
        this->Execute(m.val[2]),
        this->Execute(m.val[3]),
    };
    return r;
}
#endif
