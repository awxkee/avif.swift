//
//  Rec2408ToneMapper.hpp
//
//
//  Created by Radzivon Bartoshyk on 08/10/2023.
//

#ifndef Rec2408ToneMapper_hpp
#define Rec2408ToneMapper_hpp

#include "ToneMapper.hpp"

#include <stdio.h>

#if __arm64__
#include <arm_neon.h>
#endif

class Rec2408ToneMapper: public ToneMapper {
public:
    Rec2408ToneMapper(const float contentMaxBrightness,
                      const float displayMaxBrightness,
                      const float whitePoint): ToneMapper() {
        this->Ld = contentMaxBrightness / whitePoint;
        this->a = (displayMaxBrightness/whitePoint) / (Ld*Ld);
        this->b = 1.0f / (displayMaxBrightness/whitePoint);
#if __arm64__
        this->aVec = vdupq_n_f32(a);
        this->bVec = vdupq_n_f32(b);
        this->ones = vdupq_n_f32(1.f);
#endif
    }

    void Execute(float &r, float &g, float &b) override;
#if __arm64__
    float32x4_t Execute(const float32x4_t m) override;
    float32x4x4_t Execute(const float32x4x4_t m) override;
#endif

private:
    float Ld;
    float a;
    float b;
    float SDR(float Lin);
#if __arm64__
    float32x4_t SDR(float32x4_t Lin);
    float32x4_t aVec;
    float32x4_t bVec;
    float32x4_t ones;
    const float32x4_t luma = { 0.2627, 0.6780, 0.0593, 0.0f };
#endif
};

#endif /* Rec2408ToneMapper_hpp */
