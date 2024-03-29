//
//  MobiusToneMapper.cpp
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 09/10/2023.
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

#include "MobiusToneMapper.hpp"
#include <algorithm>

using namespace std;

#if defined(__clang__)
#pragma clang fp contract(fast) exceptions(ignore) reassociate(on)
#endif

float MobiusToneMapper::mobius(const float x)
{
    const float in = x * exposure;
    const float j = transition;
    if( in <= j )
        return in;
    const float a = -j * j * ( peak - 1.0f ) / ( j * j - 2.0f * j + peak );
    const float b = ( j * j - 2.0f * j * peak + peak ) / max( peak - 1.0f, 1e-6f );
    return ( b * b + 2.0f * b * j + j * j ) / ( b - a ) * ( in + a ) / ( in + b );
}

#if __arm64__
float32x4_t MobiusToneMapper::Execute(const float32x4_t m) {
    const float32x4_t in = vmulq_n_f32(m, exposure);
    uint32x4_t maskHigh = vcltq_f32(m, vdupq_n_f32(transition));
    float j = transition;
    const float a = -j * j * ( peak - 1.0f ) / ( j * j - 2.0f * j + peak );
    const float b = ( j * j - 2.0f * j * peak + peak ) / max( peak - 1.0f, 1e-6f );
    const float32x4_t av = vdupq_n_f32(a);
    const float32x4_t bv = vdupq_n_f32(b);
    return vdivq_f32(vmulq_f32(vaddq_f32(in, av), vdupq_n_f32(( b * b + 2.0f * b * j + j * j ) / ( b - a ))), vaddq_f32(in, bv));
}

float32x4x4_t MobiusToneMapper::Execute(const float32x4x4_t m) {
    float32x4x4_t r = {
        Execute(m.val[0]),
        Execute(m.val[1]),
        Execute(m.val[2]),
        Execute(m.val[3])
    };
    return r;
}

#endif

void MobiusToneMapper::Execute(float &r, float &g, float &b) {
    r *= exposure;
    g *= exposure;
    b *= exposure;
    r = mobius(r);
    g = mobius(g);
    b = mobius(b);
}
