//
//  UchimuraToneMapper.hpp
//  
//
//  Created by Radzivon Bartoshyk on 10/10/2023.
//

#ifndef UchimuraToneMapper_hpp
#define UchimuraToneMapper_hpp

#include <stdio.h>
#include "ToneMapper.hpp"

#if __arm64__
#include <arm_neon.h>
#endif

class UchimuraToneMapper: public ToneMapper {
public:
    UchimuraToneMapper(): exposure(1.0f) {

    }

    ~UchimuraToneMapper() {

    }

    void Execute(float &r, float &g, float &b) override;
#if __arm64__
    float32x4_t Execute(const float32x4_t m) override;
    float32x4x4_t Execute(const float32x4x4_t m) override;
#endif
private:
    const float exposure;
    float uchimura(const float v, const float exposure);
};

#endif /* UchimuraToneMapper_hpp */
