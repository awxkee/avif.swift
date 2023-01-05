//
//  AVIFDataDecoder.m
//
//  Created by Radzivon Bartoshyk on 01/05/2022.
//

#import <Foundation/Foundation.h>
#import "libyuv.h"
#if __has_include(<libavif/avif.h>)
#import <libavif/avif.h>
#else
#import "avif/avif.h"
#endif
#import <Accelerate/Accelerate.h>
#import "AVIFDataDecoder.h"
#import "AVIFRGBAMultiplier.h"
#import <vector>

@implementation AVIFDataDecoder {
    avifDecoder *_idec;
}

- (void)dealloc {
    if (_idec) {
        avifDecoderDestroy(_idec);
        _idec = NULL;
    }
}

void sharedDecoderDeallocator(avifDecoder* d) {
    avifDecoderDestroy(d);
}

- (nullable Image *)incrementallyDecodeData:(NSData *)data {
    
    if (!_idec) {
        _idec = avifDecoderCreate();
        // Disable strict mode to keep some AVIF image compatible
        _idec->strictFlags = AVIF_STRICT_DISABLED;
        if (!_idec) {
            return nil;
        }
        
    }
    
    avifDecoderSetIOMemory(_idec, reinterpret_cast<const uint8_t *>(data.bytes), data.length);
    avifResult decodeResult = avifDecoderParse(_idec);
    
    if (decodeResult != AVIF_RESULT_OK && decodeResult != AVIF_RESULT_TRUNCATED_DATA) {
        NSLog(@"Failed to decode image: %s", avifResultToString(decodeResult));
        avifDecoderDestroy(_idec);
        _idec = NULL;
        return nil;
    }
    
    if (!_idec->allowProgressive) {
        NSLog(@"Progressive decoding is not allowed");
    }
    
    // Static image
    if (_idec->imageCount >= 1) {
        avifResult nextImageResult = avifDecoderNextImage(_idec);
        avifRGBImage rgbImage;
        avifRGBImageSetDefaults(&rgbImage, _idec->image);
        rgbImage.format = AVIF_RGB_FORMAT_RGBA;
        rgbImage.alphaPremultiplied = true;
        rgbImage.depth = 8;
        avifRGBImageAllocatePixels(&rgbImage);
        avifResult rgbResult = avifImageYUVToRGB(_idec->image, &rgbImage);
        if (rgbResult != AVIF_RESULT_OK) {
            NSLog(@"avifImageYUVToRGB %s", avifResultToString(nextImageResult));

            avifRGBImageFreePixels(&rgbImage);
            avifDecoderDestroy(_idec);
            _idec = NULL;
            return nil;
        }
        
        int newWidth = rgbImage.width;
        int newHeight = rgbImage.height;
        int newRowBytes = rgbImage.rowBytes;
        int depth = rgbImage.depth;
        int stride = rgbImage.rowBytes;
        auto pixelsData = malloc(stride * newHeight);
        memcpy(pixelsData, rgbImage.pixels, stride * newHeight);
        avifRGBImageFreePixels(&rgbImage);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        int flags = kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast;
        CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixelsData, stride*newHeight, AV1CGDataProviderReleaseDataCallback);
        if (!provider) {
            free(pixelsData);
            CGColorSpaceRelease(colorSpace);
            return NULL;
        }
        CGImageRef imageRef = CGImageCreate(newWidth, newHeight, depth, 32, newRowBytes, colorSpace, flags, provider, NULL, false, kCGRenderingIntentDefault);
        Image *image = nil;
#if AVIF_PLUGIN_MAC
        image = [[NSImage alloc] initWithCGImage:imageRef size:CGSizeZero];
#else
        image = [UIImage imageWithCGImage:imageRef scale:1 orientation: UIImageOrientationUp];
#endif

        CGDataProviderRelease(provider);
        CGImageRelease(imageRef);
        CGColorSpaceRelease(colorSpace);
        return image;
    } else if (_idec->imageCount < 1) {
        NSLog(@"AVIF Data decoder: image is not already allocated... continue decoding...");
        return nil;
    }
    return nil;
}

- (nullable NSValue*)readSize:(nonnull NSData*)data error:(NSError *_Nullable * _Nullable)error {
    avifDecoder * decoder = avifDecoderCreate();
    avifDecoderSetIOMemory(decoder, reinterpret_cast<const uint8_t *>(data.bytes), data.length);
    
    // Disable strict mode to keep some AVIF image compatible
    decoder->strictFlags = AVIF_STRICT_DISABLED;
    avifResult decodeResult = avifDecoderParse(decoder);
    if (decodeResult != AVIF_RESULT_OK) {
        NSLog(@"Failed to decode image: %s", avifResultToString(decodeResult));
        avifDecoderDestroy(decoder);
        *error = [[NSError alloc] initWithDomain:@"AVIF" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"readSize in AVIF failed with result: %s", avifResultToString(decodeResult)] }];
        return nil;
    }
    
    CGSize size = CGSizeMake(decoder->image->width, decoder->image->height);
    
    avifDecoderDestroy(decoder);
#if TARGET_OS_OSX
    return [NSValue valueWithSize:size];
#else
    return [NSValue valueWithCGSize:size];
#endif
}

- (nullable NSValue*)readSizeFromPath:(nonnull NSString*)path error:(NSError *_Nullable * _Nullable)error {
    avifDecoder * decoder = avifDecoderCreate();
    avifDecoderSetIOFile(decoder, [path UTF8String]);
    
    // Disable strict mode to keep some AVIF image compatible
    decoder->strictFlags = AVIF_STRICT_DISABLED;
    avifResult decodeResult = avifDecoderParse(decoder);
    if (decodeResult != AVIF_RESULT_OK) {
        avifDecoderDestroy(decoder);
        *error = [[NSError alloc] initWithDomain:@"AVIF" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"readSize in AVIF failed with result: %s", avifResultToString(decodeResult)] }];
        return nil;
    }
    
    CGSize size = CGSizeMake(decoder->image->width, decoder->image->height);
    
    avifDecoderDestroy(decoder);
    
#if TARGET_OS_OSX
    return [NSValue valueWithSize:size];
#else
    return [NSValue valueWithCGSize:size];
#endif
}

- (nullable Image *)decode:(nonnull NSInputStream *)inputStream sampleSize:(CGSize)sampleSize maxContentSize:(NSUInteger)maxContentSize error:(NSError *_Nullable * _Nullable)error {
    NSInteger result;
    int bufferLength = 30196;
    uint8_t buffer[bufferLength];
    NSMutableData* data = [[NSMutableData alloc] init];
    [inputStream open];
    while((result = [inputStream read:buffer maxLength:bufferLength]) != 0) {
        if(result > 0) {
            [data appendBytes:&buffer[0] length:result];
            if (maxContentSize > 0 && data.length > maxContentSize) {
                *error = [[NSError alloc] initWithDomain:@"AVIF" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Content limit exceeded" }];
                [inputStream close];
                return nil;
            }
        } else {
            *error = [inputStream streamError];
            [inputStream close];
            return nil;
        }
    }
    [inputStream close];
    std::shared_ptr<avifDecoder> decoder(avifDecoderCreate(), sharedDecoderDeallocator);

    avifDecoderSetIOMemory(decoder.get(), reinterpret_cast<const uint8_t *>(data.bytes), data.length);
    CGFloat scale = 1;
    
    // Disable strict mode to keep some AVIF image compatible
    decoder->strictFlags = AVIF_STRICT_DISABLED;
    decoder->ignoreXMP = true;
    decoder->ignoreExif = true;
    avifResult decodeResult = avifDecoderParse(decoder.get());
    if (decodeResult != AVIF_RESULT_OK) {
        NSLog(@"Failed to decode image: %s", avifResultToString(decodeResult));
        *error = [[NSError alloc] initWithDomain:@"AVIF" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Decoding AVIF failed with: %s", avifResultToString(decodeResult)] }];
        return nil;
    }
    // Static image
    avifResult nextImageResult = avifDecoderNextImage(decoder.get());
    if (nextImageResult != AVIF_RESULT_OK) {
        NSLog(@"Failed to decode image: %s", avifResultToString(nextImageResult));
        *error = [[NSError alloc] initWithDomain:@"AVIF" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Decoding AVIF failed with: %s", avifResultToString(nextImageResult)] }];
        return nil;
    }
    
    if (!CGSizeEqualToSize(CGSizeZero, sampleSize)) {
        
        float imageAspectRatio = (float)decoder->image->width / (float)decoder->image->height;
        float canvasRatio = sampleSize.width / sampleSize.height;
        
        float resizeFactor = 1.0f;
        
        if (imageAspectRatio > canvasRatio) {
            resizeFactor = sampleSize.width / (float)decoder->image->width;
        } else {
            resizeFactor = sampleSize.height / (float)decoder->image->width;
        }
        
        if (!avifImageScale(decoder->image, (float)decoder->image->width*resizeFactor, (float)decoder->image->height*resizeFactor, AVIF_DEFAULT_IMAGE_SIZE_LIMIT, (uint32_t) maxContentSize, &decoder->diag)) {
            return nil;
        }
        
    }
    avifRGBImage rgbImage;
    avifRGBImageSetDefaults(&rgbImage, decoder->image);
    rgbImage.format = AVIF_RGB_FORMAT_RGBA;
    rgbImage.alphaPremultiplied = true;
    rgbImage.depth = 8;
    avifRGBImageAllocatePixels(&rgbImage);
    avifResult rgbResult = avifImageYUVToRGB(decoder->image, &rgbImage);
    if (rgbResult != AVIF_RESULT_OK) {
        avifRGBImageFreePixels(&rgbImage);
        *error = [[NSError alloc] initWithDomain:@"AVIF" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Decoding AVIF failed with: %s", avifResultToString(rgbResult)] }];
        return nil;
    }
    
    int newWidth = rgbImage.width;
    int newHeight = rgbImage.height;
    int newRowBytes = rgbImage.rowBytes;
    int depth = rgbImage.depth;
    int stride = rgbImage.rowBytes;
    auto pixelsData = malloc(stride * newHeight);
    memcpy(pixelsData, rgbImage.pixels, stride * newHeight);
    avifRGBImageFreePixels(&rgbImage);
    decoder.reset();
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    int flags = kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast;
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixelsData, stride*newHeight, AV1CGDataProviderReleaseDataCallback);
    if (!provider) {
        free(pixelsData);
        CGColorSpaceRelease(colorSpace);
        return NULL;
    }
    
    CGImageRef imageRef = CGImageCreate(newWidth, newHeight, depth, 32, newRowBytes, colorSpace, flags, provider, NULL, false, kCGRenderingIntentDefault);
    Image *image = nil;
#if AVIF_PLUGIN_MAC
    image = [[NSImage alloc] initWithCGImage:imageRef size:CGSizeZero];
#else
    image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
#endif

    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    CGImageRelease(imageRef);
    return image;
}

@end
