//
//  MobiusToneMapper.hpp
//  
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
//

#ifndef MobiusToneMapper_hpp
#define MobiusToneMapper_hpp

#include "ToneMapper.hpp"
#include <stdio.h>

#if __arm64__
#include <arm_neon.h>
#endif

class MobiusToneMapper: public ToneMapper {
public:
    MobiusToneMapper(const float exposure = 1.2f, const float transition = 0.9f, const float peak = 1.0f): ToneMapper() {
        this->exposure = exposure;
        this->transition = transition;
        this->peak = peak;
    }

    ~MobiusToneMapper() {
        
    }

    void Execute(float &r, float &g, float &b) override;

#if __arm64__
    float32x4_t Execute(const float32x4_t m) override;
    float32x4x4_t Execute(const float32x4x4_t m) override;
#endif

private:
    float exposure;
    float transition;
    float peak;

    float mobius(const float x);
};

#endif /* MobiusToneMapper_hpp */
