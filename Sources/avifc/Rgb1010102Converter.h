//
//  Rgb1010102Converter.h
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

#ifndef Rgb1010102Converter_h
#define Rgb1010102Converter_h

@interface Rgb1010102Converter : NSObject
+(bool)F16ToRGBA1010102:(nonnull const uint8_t*)data stride:(const int)stride dst:(nonnull uint8_t*)dst dstStride:(const int)dstStride width:(const int)width height:(const int)height components:(const int)components;
+(bool)F16ToRGBA1010102Impl:(nonnull const uint8_t*)src stride:(const int)stride dst:(nonnull uint8_t*)dst dstStride:(const int)dstStride width:(const int)width height:(const int)height components:(const int)components;
@end

#endif /* Rgb1010102Converter_h */
