//
//  RgbTransfer.mm
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
#import "RgbTransfer.h"
#import "Accelerate/Accelerate.h"

@implementation RgbTransfer

+(bool)CopyBuffer:(nonnull uint8_t*)src dst:(nonnull uint8_t*)dst stride:(int)stride width:(int)width height:(int)height pixelSize:(int)pixelSize components:(int)components {
    vImage_Buffer srcBuffer = {
        .data = (void*)src,
        .width = static_cast<vImagePixelCount>(width * components),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<size_t>(stride)
    };

    vImage_Buffer dstBuffer = {
        .data = dst,
        .width = static_cast<vImagePixelCount>(width * components),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<size_t>(stride)
    };
    vImage_Error vEerror = vImageCopyBuffer(&srcBuffer, &dstBuffer, static_cast<size_t>(pixelSize), kvImageNoFlags);
    if (vEerror != kvImageNoError) {
        return false;
    }
    return true;
}

@end
