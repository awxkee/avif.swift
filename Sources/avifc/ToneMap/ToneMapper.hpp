//
//  ToneMapper.hpp
//  
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
//

#ifndef ToneMapper_hpp
#define ToneMapper_hpp

#include <stdio.h>

#if __arm64__
#include <arm_neon.h>
#endif

class ToneMapper {

public:
    ToneMapper() {
        
    }
    virtual ~ToneMapper() { };
    virtual void Execute(float& r, float& g, float& b) = 0;

#if __arm64__
    virtual float32x4x4_t Execute(const float32x4x4_t m) = 0;
    virtual float32x4_t Execute(const float32x4_t m) = 0;
#endif
};

#endif /* ToneMapper_hpp */
