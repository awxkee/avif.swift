//
//  math_expf.cpp
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 11/10/2023.
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

#include "MathExpf.hpp"

#if defined(__clang__)
#pragma clang fp contract(fast) exceptions(ignore) reassociate(on)
#endif

/*
Based on:

        e ^ x = (1+m) * (2^n)
        x = log(1+m) + n * log(2)
        n = (int) (x * 1.0 / log(2))
        (1+m) = e ^ (x - n * log(2))
        (1+m) = Poly(x - n * log(2))

        where Poly(x) is the Minimax approximation of e ^ x over the
        range [-Log(2), Log(2)]

Test func : expf(x)
Test Range: 0 < x < 50
Peak Error:    ~0.00024%
RMS  Error: ~0.00007%
*/

#include "math.h"

const float __expf_rng[2] = {
    1.442695041f,
    0.693147180f
};

const float __expf_lut[8] = {
    0.9999999916728642,        //p0
    0.04165989275009526,     //p4
    0.5000006143673624,     //p2
    0.0014122663401803872,     //p6
    1.000000059694879,         //p1
    0.008336936973260111,     //p5
    0.16666570253074878,     //p3
    0.00019578093328483123    //p7
};

float expf_c(float x)
{
    float a, b, c, d, xx;
    int m;

    union {
        float   f;
        int     i;
    } r;

    //Range Reduction:
    m = (int) (x * __expf_rng[0]);
    x = x - ((float) m) * __expf_rng[1];

    //Taylor Polynomial (Estrins)
    a = (__expf_lut[4] * x) + (__expf_lut[0]);
    b = (__expf_lut[6] * x) + (__expf_lut[2]);
    c = (__expf_lut[5] * x) + (__expf_lut[1]);
    d = (__expf_lut[7] * x) + (__expf_lut[3]);
    xx = x * x;
    a = a + b * xx;
    c = c + d * xx;
    xx = xx* xx;
    r.f = a + c * xx;

    //multiply by 2 ^ m
    m = m << 23;
    r.i = r.i + m;

    return r.f;
}
