//
//  math_fabs.cpp
//  
//
//  Created by Radzivon Bartoshyk on 10/10/2023.
//

#include "math_fabs.hpp"

#if defined(__clang__)
#pragma clang fp contract(fast) exceptions(ignore) reassociate(on)
#endif

float fabsf_c(float x)
{
    union {
        int i;
        float f;
    } xx;

    xx.f = x;
    xx.i = xx.i & 0x7FFFFFFF;
    return xx.f;
}
