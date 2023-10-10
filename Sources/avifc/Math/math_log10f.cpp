//
//  math_log10f.cpp
//  
//
//  Created by Radzivon Bartoshyk on 10/10/2023.
//

#include "math_log10f.hpp"
#include "math.h"

#if defined(__clang__)
#pragma clang fp contract(fast) exceptions(ignore) reassociate(on)
#endif

const float __log10f_rng =  0.3010299957f;

const float __log10f_lut[8] = {
    -0.99697286229624,         //p0
    -1.07301643912502,         //p4
    -2.46980061535534,         //p2
    -0.07176870463131,         //p6
    2.247870219989470,         //p1
    0.366547581117400,         //p5
    1.991005185100089,         //p3
    0.006135635201050,        //p7
};

float log10f_c(float x)
{
    float a, b, c, d, xx;
    int m;

    union {
        float   f;
        int     i;
    } r;

    //extract exponent
    r.f = x;
    m = (r.i >> 23);
    m = m - 127;
    r.i = r.i - (m << 23);

    //Taylor Polynomial (Estrins)
    xx = r.f * r.f;
    a = (__log10f_lut[4] * r.f) + (__log10f_lut[0]);
    b = (__log10f_lut[6] * r.f) + (__log10f_lut[2]);
    c = (__log10f_lut[5] * r.f) + (__log10f_lut[1]);
    d = (__log10f_lut[7] * r.f) + (__log10f_lut[3]);
    a = a + b * xx;
    c = c + d * xx;
    xx = xx * xx;
    r.f = a + c * xx;

    //add exponent
    r.f = r.f + ((float) m) * __log10f_rng;

    return r.f;
}
