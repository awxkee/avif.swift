//
//  AldridgeFilmicToneMapper.hpp
//  
//
//  Created by Radzivon Bartoshyk on 10/10/2023.
//

#ifndef AldridgeFilmicToneMapper_hpp
#define AldridgeFilmicToneMapper_hpp

#include <stdio.h>
#include "ToneMapper.hpp"

#if __arm64__
#include <arm_neon.h>
#endif

class AldridgeFilmicToneMapper: public ToneMapper {
public:
    AldridgeFilmicToneMapper(): exposure(1.0f), cutoff(0.025f) {

    }

    ~AldridgeFilmicToneMapper() {

    }

    void Execute(float &r, float &g, float &b) override;
#if __arm64__
    float32x4_t Execute(const float32x4_t m) override;
    float32x4x4_t Execute(const float32x4x4_t m) override;
#endif
private:
    const float exposure;
    const float cutoff;
    float aldridge(const float x, const float exposure);
};

#endif /* AldridgeFilmicToneMapper_hpp */
