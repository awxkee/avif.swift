//
//  Rgb1010102Converter.mm
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 10/09/2022.
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


#import <Foundation/Foundation.h>
#import "Rgb1010102Converter.h"
#import "Accelerate/Accelerate.h"
#import <vector>

@implementation Rgb1010102Converter: NSObject

+(bool)F16ToU16:(nonnull uint8_t*)src dst:(nonnull uint8_t*)dst stride:(int)stride width:(int)width height:(int)height {
    vImage_Buffer srcBuffer = {
        .data = (void*)src,
        .width = static_cast<vImagePixelCount>(width * 4),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<size_t>(stride)
    };

    vImage_Buffer dstBuffer = {
        .data = dst,
        .width = static_cast<vImagePixelCount>(width * 4),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<size_t>(stride)
    };
    const float scale = 1.0f / float((1 << 10) - 1);
    vImage_Error vEerror = vImageConvert_16Fto16U(&srcBuffer, &dstBuffer,kvImageNoFlags);
    if (vEerror != kvImageNoError) {
        return false;
    }

    vImage_Buffer permuteBuffer = {
        .data = dst,
        .width = static_cast<vImagePixelCount>(width),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<size_t>(stride)
    };
    const uint8_t permuteMap[4] = { 3,0,1,2 };
    vEerror = vImagePermuteChannels_ARGB16U(&permuteBuffer, &permuteBuffer, permuteMap, kvImageNoFlags);
    if (vEerror != kvImageNoError) {
        return false;
    }

    return true;
}

+(bool)F16ToRGBA1010102:(nonnull uint8_t*)data dst:(nonnull uint8_t*)dst stride:(nonnull int*)stride width:(int)width height:(int)height {
    std::vector<uint8_t> intermediateBuffer(height * (*stride));
    if (![self F16ToU16:data dst:intermediateBuffer.data() stride:*stride width:width height:height]) {
        return false;
    }

    int newStride = width * sizeof(uint8_t) * 4;

    vImage_Buffer srcBuffer = {
        .data = (void*)intermediateBuffer.data(),
        .width = static_cast<vImagePixelCount>(width),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<size_t>(*stride)
    };

    vImage_Buffer dstBuffer = {
        .data = dst,
        .width = static_cast<vImagePixelCount>(width),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<size_t>(newStride)
    };
    const float scale = powf(2, 10) - 1;
    const uint8_t permuteMap[4] = { 0,1,2,3 };
    vImage_Error vEerror = vImageConvert_ARGB16UToRGBA1010102(&srcBuffer, &dstBuffer, 0, (int32_t)scale, permuteMap, kvImageNoFlags);
    if (vEerror != kvImageNoError) {
        return false;
    }

    *stride = newStride;
    return true;
}

@end
