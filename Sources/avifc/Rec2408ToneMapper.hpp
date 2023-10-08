//
//  Rec2408ToneMapper.hpp
//
//
//  Created by Radzivon Bartoshyk on 08/10/2023.
//

#ifndef Rec2408ToneMapper_hpp
#define Rec2408ToneMapper_hpp

#include <stdio.h>

#if __arm64__
#include <arm_neon.h>
#endif

class Rec2408ToneMapper {
public:
    Rec2408ToneMapper(const float contentMaxBrightness, const float displayMaxBrightness, const float whitePoint) {
        this->Ld = contentMaxBrightness / whitePoint;
        this->a = displayMaxBrightness / (Ld*Ld);
        this->b = 1.0f / displayMaxBrightness;
#if __arm64__
        this->aVec = vdupq_n_f32(a);
        this->bVec = vdupq_n_f32(b);
        this->ones = vdupq_n_f32(1.f);
#endif
    }

    void toneMap(float& r, float &g, float& b);

#if __arm64__
    float32x4x4_t toneMap(const float32x4x4_t m);
    float32x4_t toneMap(const float32x4_t m);
#endif

private:
    float Ld;
    float a;
    float b;

#if __arm64__
    float32x4_t aVec;
    float32x4_t bVec;
    float32x4_t ones;
    const float32x4_t luma = { 0.2627, 0.6780, 0.0593, 0.0f };
#endif
};

#endif /* Rec2408ToneMapper_hpp */
