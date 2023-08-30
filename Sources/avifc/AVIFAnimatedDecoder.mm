//
//  AVIFAnimatedDecoder.m
//  
//
//  Created by Radzivon Bartoshyk on 22/06/2022.
//

#import "AVIFAnimatedDecoder.h"
#import "avif/avif.h"
#import <Accelerate/Accelerate.h>
#import "AVIFRGBAMultiplier.h"
#import "PlatformImage.h"

@implementation AVIFAnimatedDecoder {
    avifDecoder *_idec;
}

-(nullable id)initWithData:(nonnull NSData*)data {
    _idec = avifDecoderCreate();

    avifDecoderSetIOMemory(_idec, reinterpret_cast<const uint8_t*>(data.bytes), data.length);
    CGFloat scale = 1;
    
    _idec->strictFlags = AVIF_STRICT_DISABLED;
    _idec->ignoreXMP = true;
    _idec->ignoreExif = true;
    avifResult decodeResult = avifDecoderParse(_idec);
    if (decodeResult != AVIF_RESULT_OK) {
        avifDecoderDestroy(_idec);
        return nil;
    }
    return self;
}

-(nullable Image*)getImage:(int)frame {
    CGImageRef ref = [self get:frame];
    if (!ref) return NULL;
    Image *image = nil;
#if TARGET_OS_OSX
    image = [[NSImage alloc] initWithCGImage:ref size:CGSizeZero];
#else
    image = [UIImage imageWithCGImage:ref scale:1 orientation:UIImageOrientationUp];
#endif
    return image;
}

-(nullable CGImageRef)get:(int)frame {
    avifResult nextImageResult = avifDecoderNthImage(_idec, frame);
    if (nextImageResult != AVIF_RESULT_OK) {
        return nil;
    }
    
    avifRGBImage rgbImage;
    avifRGBImageSetDefaults(&rgbImage, _idec->image);
    rgbImage.format = AVIF_RGB_FORMAT_RGBA;
    rgbImage.depth = 8;
    rgbImage.alphaPremultiplied = true;
    avifRGBImageAllocatePixels(&rgbImage);
    avifResult rgbResult = avifImageYUVToRGB(_idec->image, &rgbImage);
    if (rgbResult != AVIF_RESULT_OK) {
        avifRGBImageFreePixels(&rgbImage);
        return nil;
    }
    
    int newWidth = rgbImage.width;
    int newHeight = rgbImage.height;
    int newRowBytes = rgbImage.rowBytes;
    int depth = rgbImage.depth;
    auto storedImage = malloc(rgbImage.height * rgbImage.rowBytes);

    if (!storedImage) {
        avifRGBImageFreePixels(&rgbImage);
        return nil;
    }
    memcpy(storedImage, rgbImage.pixels, rgbImage.height * rgbImage.rowBytes);
    avifRGBImageFreePixels(&rgbImage);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    int flags = (int)kCGBitmapByteOrder32Big | (int)kCGImageAlphaPremultipliedLast;
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, storedImage, rgbImage.width*rgbImage.height*4, AV1CGDataProviderReleaseDataCallback);
    if (!provider) {
        free(storedImage);
        return NULL;
    }
    
    CGImageRef image = CGImageCreate(newWidth, newHeight, depth, 32, newRowBytes, colorSpace, flags, provider, NULL, false, kCGRenderingIntentDefault);
    return image;
}

-(int)frameDuration:(int)frame {
    avifImageTiming timing;
    avifDecoderNthImageTiming(_idec, frame, &timing);
    return (int)(1000.0f / ((float)timing.timescale) * (float)timing.durationInTimescales);
}

-(int)framesCount {
    return _idec->imageCount;
}

-(int)duration {
    return (int)(1000.0f / ((float)_idec->timescale) * (float)_idec->durationInTimescales);
}

-(CGSize)imageSize {
    return CGSizeMake(_idec->image->width, _idec->image->height);
}

- (void)dealloc {
    if (_idec) {
        avifDecoderDestroy(_idec);
        _idec = NULL;
    }
}

@end
