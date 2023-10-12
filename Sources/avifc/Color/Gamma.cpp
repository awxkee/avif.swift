//
//  Gamma.cpp
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

#include "Gamma.hpp"
#include "Math/FastMath.hpp"

#if defined(__clang__)
#pragma clang fp contract(on) exceptions(ignore) reassociate(on)
#endif

float LinearITUR709ToITUR709(const float linear) {
    if (linear <= 0.018f) {
        return 4.5f * linear;
    } else {
        return 1.099f * powf_c(linear, 0.45f) - 0.099f;
    }
}

float LinearSRGBToSRGB(const float linearValue) {
    if (linearValue <= 0.0031308) {
        return 12.92f * linearValue;
    } else {
        return 1.055f * powf_c(linearValue, 1.0f / 2.4f) - 0.055f;
    }
}

float LinearRec2020ToRec2020(const float linear) {
    if (0 <= betaRec2020 && linear < betaRec2020) {
        return 4.5f * linear;
    } else if (betaRec2020 <= linear && linear < 1) {
        return alphaRec2020 * powf_c(linear, 0.45f) - (alphaRec2020 - 1.0f);
    } else {
        return linear;
    }
}

float dciP3PQGammaCorrection(const float linear) {
    return powf_c(linear, 1.0f / 2.6f);
}
