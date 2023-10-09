//
//  HableFilmicToneMapper.hpp
//  
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
//

#ifndef HableFilmicToneMapper_hpp
#define HableFilmicToneMapper_hpp

#include <stdio.h>
#include "ToneMapper.hpp"

#if __arm64__
#include <arm_neon.h>
#endif

class HableFilmicToneMapper: public ToneMapper {
public:
    HableFilmicToneMapper(): exposure(2.0f) {

    }

    ~HableFilmicToneMapper() {

    }

    void Execute(float &r, float &g, float &b) override;
#if __arm64__
    float32x4_t Execute(const float32x4_t m) override;
    float32x4x4_t Execute(const float32x4x4_t m) override;
#endif
private:
    float hableFilmic(float v);
    float hable(const float x);
    const float whiteScale = 1.0f / hable(11.2f);
    float exposure;
};

#endif /* HableFilmicToneMapper_hpp */
