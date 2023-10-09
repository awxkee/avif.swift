//
//  HableToneMapper.hpp
//  
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
//

#ifndef HableToneMapper_hpp
#define HableToneMapper_hpp

#include <stdio.h>
#include "ToneMapper.hpp"

#if __arm64__
#include <arm_neon.h>
#endif

class HableToneMapper: public ToneMapper {
public:
    HableToneMapper() {

    }

    ~HableToneMapper() {

    }

    void Execute(float &r, float &g, float &b) override;
#if __arm64__
    float32x4_t Execute(const float32x4_t m) override;
    float32x4x4_t Execute(const float32x4x4_t m) override;
#endif
private:
    float hable(const float x);
    const float sig = hable(4.8f);
#if __arm64__
    const float32x4_t sigVec = vdupq_n_f32(hable(4.8f));
#endif
};

#endif /* HableToneMapper_hpp */
