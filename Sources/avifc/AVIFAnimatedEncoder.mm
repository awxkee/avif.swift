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

#import <Foundation/Foundation.h>
#import "AVIFAnimatedEncoder.h"
#import "avif/avif.h"
#include <vector>
#include <memory>
#import "avifpixart.h"
#import "ColorSpace.h"

static void releaseSharedAEncoderImage(avifImage* image) {
    avifImageDestroy(image);
}

@implementation AVIFAnimatedEncoder {
    avifEncoder * encoder;
}

-(void)dealloc {
    [self cleanUp];
}

- (void*)create:(PreferredCodec)preferredCodec error:(NSError * _Nullable * _Nullable)error {
    encoder = avifEncoderCreate();
    if (!encoder) {
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Encoder allocation has failed" }];
        return nil;
    }
    avifCodecChoice choice = AVIF_CODEC_CHOICE_AUTO;
    encoder->maxThreads = 6;
    encoder->timescale = 1000;
    switch (preferredCodec) {
        case kAOM:
            {
                choice = avifCodecChoiceFromName("aom");
            }
            break;
        case kSVTAV1:
            {
                choice = avifCodecChoiceFromName("svt");
            }
            break;
    }
    encoder->codecChoice = choice;

    return (__bridge void * _Nullable)(self);
}

- (void* _Nullable)addImage:(Image * _Nonnull)platformImage duration:(NSUInteger)duration error:(NSError * _Nullable * _Nullable)error {
    if (!encoder) {
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Encoder aws not allocated" }];
        return nil;
    }
    uint32_t width;
    uint32_t height;
    auto sourceImage = [platformImage rgbaPixels:&width imageHeight:&height];
    if (!sourceImage) {
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder"
                                            code:500
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Fetching image pixels has failed" }];
        return nil;
    }
    
    auto img = avifImageCreate(width, height, (uint32_t)8, AVIF_PIXEL_FORMAT_YUV420);

    if (!img) {
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder"
                                            code:500
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Memory allocation for image has failed" }];
        return nil;
    }
    
    std::shared_ptr<avifImage> image(img, releaseSharedAEncoderImage);
    
    if (sourceImage.sourceHasAlpha) {
        if (avifImageAllocatePlanes(image.get(), AVIF_PLANES_ALL) != AVIF_RESULT_OK) {
            *error = [[NSError alloc] initWithDomain:@"AVIFEncoder"
                                                code:500
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Memory allocation for image has failed" }];
            return nil;
        }
    } else {
        if (avifImageAllocatePlanes(image.get(), AVIF_PLANES_YUV) != AVIF_RESULT_OK) {
            *error = [[NSError alloc] initWithDomain:@"AVIFEncoder"
                                                code:500
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Memory allocation for image has failed" }];
            return nil;
        }
    }
    
    [ColorSpace apply:image.get() colorSpace: [sourceImage colorSpace]];
        
    YuvMatrix matrix = YuvMatrix::Bt709;
    
    if (image->matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_BT2020_NCL) {
        matrix = YuvMatrix::Bt2020;
    }
    
    pixart_rgba8_to_yuv8(image->yuvPlanes[0], image->yuvRowBytes[0],
                         image->yuvPlanes[1], image->yuvRowBytes[1],
                         image->yuvPlanes[2], image->yuvRowBytes[2],
                         [sourceImage data], width * 4,
                         width, height,
                         YuvRange::Tv, YuvMatrix::YCgCo, YuvType::Yuv420);
    
    image->matrixCoefficients = AVIF_MATRIX_COEFFICIENTS_YCGCO;
    image->yuvRange = AVIF_RANGE_LIMITED;
    
    avifResult addImageResult = avifEncoderAddImage(encoder, image.get(), (int)round(1000.0f * (float)duration), AVIF_ADD_IMAGE_FLAG_NONE);
    if (addImageResult != AVIF_RESULT_OK) {
        [self cleanUp];
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"add image failed with result: %s", avifResultToString(addImageResult)] }];
        return nil;
    }
    
    return (__bridge void * _Nullable)(self);
}

- (void)setCompressionQuality:(double)quality {
    int rescaledQuality = AVIF_QUANTIZER_WORST_QUALITY - (int)((quality) * AVIF_QUANTIZER_WORST_QUALITY);
    if (encoder) {
        encoder->minQuantizer = rescaledQuality;
        encoder->maxQuantizer = rescaledQuality;
    }
}

- (void)setLoopsCount:(NSInteger)loopsCount {
    if (encoder) {
        encoder->repetitionCount = static_cast<int>(loopsCount);
    }
}

- (NSData* _Nullable)encode:(NSError * _Nullable *_Nullable)error {
    if (!encoder) {
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Encoder aws not allocated" }];
        return nil;
    }
    avifRWData avifOutput = AVIF_DATA_EMPTY;
    avifResult finishResult = avifEncoderFinish(encoder, &avifOutput);
    if (finishResult != AVIF_RESULT_OK) {
        [self cleanUp];
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" 
                                            code:500
                                        userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"encoding failed with result: %s", avifResultToString(finishResult)] }];
        return nil;
    }
    
    NSData *result = [[NSData alloc] initWithBytes:avifOutput.data length:avifOutput.size];
    
    avifRWDataFree(&avifOutput);
    [self cleanUp];
    
    return result;
}

- (void)setSpeed:(NSInteger)speed {
    if (encoder) {
        encoder->speed = (int)MAX(MIN(speed, AVIF_SPEED_FASTEST), AVIF_SPEED_SLOWEST);
    }
}

- (void)cleanUp {
    if (encoder) {
        avifEncoderDestroy(encoder);
        encoder = nil;
    }
}

@end
