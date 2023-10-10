//
//  AVIFDataDecoder.mm
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 01/05/2022.
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

#import "AVIFImageMacros.h"
#import "AVIFEncoding.h"
#import "PlatformImage.h"
#if __has_include(<libavif/avif.h>)
#import <libavif/avif.h>
#else
#import "avif/avif.h"
#endif

@interface AVIFDataDecoder : NSObject

- (nullable Image *)incrementallyDecodeData:(nonnull NSData *)data;
- (nullable Image *)decode:(nonnull NSInputStream *)inputStream sampleSize:(CGSize)sampleSize maxContentSize:(NSUInteger)maxContentSize scale:(CGFloat)scale error:(NSError *_Nullable * _Nullable)error;
- (nullable NSValue*)readSize:(nonnull NSData*)data error:(NSError *_Nullable * _Nullable)error;
- (nullable NSValue*)readSizeFromPath:(nonnull NSString*)path error:(NSError *_Nullable * _Nullable)error;

@end
