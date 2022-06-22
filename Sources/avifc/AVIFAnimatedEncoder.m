//
//  AVIFAnimatedEncoder.m
//
//  Created by Radzivon Bartoshyk on 04/05/2022.
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

- (void)create {
    encoder = avifEncoderCreate();
    encoder->maxThreads = 6;
    encoder->timescale = 60;
}

- (void* _Nullable)addImage:(Image * _Nonnull)platformImage duration:(NSUInteger)duration error:(NSError * _Nullable * _Nullable)error {
    unsigned char * rgba = [platformImage rgbaPixels];
    int width = [platformImage size].width * [platformImage scale];
    int height = [platformImage size].height * [platformImage scale];
    avifRGBImage rgb;
    avifImage * image = avifImageCreate(width, height, 8, AVIF_PIXEL_FORMAT_YUV420);
    avifRGBImageSetDefaults(&rgb, image);
    avifRGBImageAllocatePixels(&rgb);
    memcpy(rgb.pixels, rgba, rgb.rowBytes * image->height);
    
    free(rgba);
    
    avifResult convertResult = avifImageRGBToYUV(image, &rgb);
    if (convertResult != AVIF_RESULT_OK) {
        avifRGBImageFreePixels(&rgb);
        avifImageDestroy(image);
        [self cleanUp];
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"convert to YUV failed with result: %s", avifResultToString(convertResult)] }];
        return nil;
    }
    
    avifResult addImageResult = avifEncoderAddImage(encoder, image, (int)round(1000.0f / 60.0f * (float)duration), AVIF_ADD_IMAGE_FLAG_NONE);
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

- (NSData* _Nullable)encode:(NSError * _Nullable *_Nullable)error {
    avifRWData avifOutput = AVIF_DATA_EMPTY;
    avifResult finishResult = avifEncoderFinish(encoder, &avifOutput);
    if (finishResult != AVIF_RESULT_OK) {
        [self cleanUp];
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"encoding failed with result: %s", avifResultToString(finishResult)] }];
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
