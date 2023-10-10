//
//  HejlBurgessToneMapper.hpp
//  
//
//  Created by Radzivon Bartoshyk on 10/10/2023.
//

#ifndef HejlBurgessToneMapper_hpp
#define HejlBurgessToneMapper_hpp

#include <stdio.h>
#include "ToneMapper.hpp"

#if __arm64__
#include <arm_neon.h>
#endif

class HejlBurgessToneMapper: public ToneMapper {
public:
    HejlBurgessToneMapper(): exposure(1.0f) {

    }

    ~HejlBurgessToneMapper() {

    }

    void Execute(float &r, float &g, float &b) override;
#if __arm64__
    float32x4_t Execute(const float32x4_t m) override;
    float32x4x4_t Execute(const float32x4x4_t m) override;
#endif
private:
    const float exposure;
    float hejlBurgess(const float x, const float exposure);
};

#endif /* HejlBurgessToneMapper_hpp */
