//
//  AVIFAnimatedEncoder.mm
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 04/05/2022.
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

#ifndef AVIFAnimatedEncoder_h
#define AVIFAnimatedEncoder_h

#include "PlatformImage.h"

@interface AVIFAnimatedEncoder : NSObject
- (nullable void*)create:(PreferredCodec)preferredCodec error:(NSError * _Nullable * _Nullable)error;
- (void* _Nullable)addImage:(Image * _Nonnull)platformImage duration:(NSUInteger)timescale error:(NSError * _Nullable * _Nullable)error;
- (NSData* _Nullable)encode:(NSError * _Nullable *_Nullable)error;
- (void)setSpeed:(NSInteger)speed;
- (void)setCompressionQuality:(double)quality;
- (void)setLoopsCount:(NSInteger)loopsCount;
- (void)cleanUp;
@end


#endif /* AVIFAnimatedEncoder_h */
