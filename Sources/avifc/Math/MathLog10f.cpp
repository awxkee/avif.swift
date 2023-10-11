//
//  MathLog10f.cpp
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 10/10/2023.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#include "MathLog10f.hpp"
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
