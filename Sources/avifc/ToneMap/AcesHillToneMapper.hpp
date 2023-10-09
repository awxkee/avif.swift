//
//  AcesHillToneMapper.hpp
//  
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
//

#ifndef AcesHillToneMapper_hpp
#define AcesHillToneMapper_hpp

#include <stdio.h>
#include "ToneMapper.hpp"

#if __arm64__
#include <arm_neon.h>
#endif

class AcesHillToneMapper: public ToneMapper {
public:
    AcesHillToneMapper(): exposure(1.5f) {

    }

    ~AcesHillToneMapper() {

    }

    void Execute(float &r, float &g, float &b) override;
#if __arm64__
    float32x4_t Execute(const float32x4_t m) override;
    float32x4x4_t Execute(const float32x4x4_t m) override;
#endif
private:
    const float exposure;
};

#endif /* AcesHillToneMapper_hpp */
