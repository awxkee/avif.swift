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
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Encoder is not allocation" }];
        return nil;
    }
    int width;
    int height;
    unsigned char * rgba = [platformImage rgbaPixels:&width imageHeight:&height];
    if (!rgba) {
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder"
                                            code:500
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Fetching image pixels has failed" }];
        return nil;
    }
    avifRGBImage rgb;
    avifImage * image = avifImageCreate(width, height, 8, AVIF_PIXEL_FORMAT_YUV420);
    if (!image) {
        free(rgba);
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Memory allocation for image has failed" }];
        return nil;
    }
    avifRGBImageSetDefaults(&rgb, image);
    avifResult convertResult = avifRGBImageAllocatePixels(&rgb);
    if (convertResult != AVIF_RESULT_OK) {
        avifImageDestroy(image);
        [self cleanUp];
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" code:500 
                                        userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"allocating RGB planes has failed: %s", avifResultToString(convertResult)] }];
        return nil;
    }
    rgb.depth = 8;
    rgb.alphaPremultiplied = false;
    memcpy(rgb.pixels, rgba, rgb.rowBytes * image->height);
    
    free(rgba);
    
    convertResult = avifImageRGBToYUV(image, &rgb);
    if (convertResult != AVIF_RESULT_OK) {
        avifRGBImageFreePixels(&rgb);
        avifImageDestroy(image);
        [self cleanUp];
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"convert to YUV failed with result: %s", avifResultToString(convertResult)] }];
        return nil;
    }
    
    avifResult addImageResult = avifEncoderAddImage(encoder, image, (int)round(1000.0f * (float)duration), AVIF_ADD_IMAGE_FLAG_NONE);
    if (addImageResult != AVIF_RESULT_OK) {
        avifRGBImageFreePixels(&rgb);
        avifImageDestroy(image);
        [self cleanUp];
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"add image failed with result: %s", avifResultToString(addImageResult)] }];
        return nil;
    }
    
    avifRGBImageFreePixels(&rgb);
    avifImageDestroy(image);
    
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
