//
//  AVIFImageXForm.m
//  
//
//  Created by Radzivon Bartoshyk on 02/09/2023.
//

#import <Foundation/Foundation.h>
#import "AVIFImageXForm.h"
#import <vector>
#import <Accelerate/Accelerate.h>
#import <CoreGraphics/CoreGraphics.h>

@implementation AVIFImageXForm

- (_Nullable CGImageRef)formCGImage:(nonnull avifDecoder*)decoder scale:(CGFloat)scale {
    avifRGBImage rgbImage;
    avifRGBImageSetDefaults(&rgbImage, decoder->image);
    rgbImage.format = AVIF_RGB_FORMAT_RGBA;

    auto colorPrimaries = decoder->image->colorPrimaries;
    auto transferCharacteristics = decoder->image->transferCharacteristics;

    bool isImageRequires64Bit = avifImageUsesU16(decoder->image);
    if (isImageRequires64Bit) {
        rgbImage.alphaPremultiplied = true;
        rgbImage.isFloat = true;
        rgbImage.depth = 16;
        rgbImage.format = AVIF_RGB_FORMAT_RGBA;
    } else {
        rgbImage.alphaPremultiplied = true;
        rgbImage.depth = 8;
    }
    avifRGBImageAllocatePixels(&rgbImage);
    avifResult rgbResult = avifImageYUVToRGB(decoder->image, &rgbImage);
    if (rgbResult != AVIF_RESULT_OK) {
        avifRGBImageFreePixels(&rgbImage);
        return nil;
    }

    int newWidth = rgbImage.width;
    int newHeight = rgbImage.height;
    int newRowBytes = rgbImage.rowBytes;
    int depth = isImageRequires64Bit ? 16 : 8;
    int stride = rgbImage.rowBytes;
    auto pixelsData = reinterpret_cast<unsigned char*>(malloc(stride * newHeight));
    memcpy(pixelsData, rgbImage.pixels, stride * newHeight);
    avifRGBImageFreePixels(&rgbImage);

    CGColorSpaceRef colorSpace;
    if(decoder->image->icc.data && decoder->image->icc.size) {
        CFDataRef iccData = CFDataCreate(kCFAllocatorDefault, decoder->image->icc.data, decoder->image->icc.size);
        colorSpace = CGColorSpaceCreateWithICCData(iccData);
        CFRelease(iccData);
    } else {
        if (colorPrimaries == AVIF_COLOR_PRIMARIES_BT709 &&
            transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_BT709) {
            CGColorSpaceRef bt709 = NULL;
            if (@available(macOS 10.11, iOS 9.0, tvOS 9.0, *)) {
                bt709 = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
            } else {
                bt709 = CGColorSpaceCreateDeviceRGB();
            }
            colorSpace = bt709;
        }
        else if(colorPrimaries == AVIF_COLOR_PRIMARIES_BT709 /* sRGB */ &&
                transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_SRGB) {
            CGColorSpaceRef sRGB = NULL;
            if (@available(macOS 10.5, iOS 9.0, tvOS 9.0, *)) {
                sRGB = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            } else {
                sRGB = CGColorSpaceCreateDeviceRGB();
            }
            colorSpace = sRGB;
        }
        else if(colorPrimaries == AVIF_COLOR_PRIMARIES_BT709 /* sRGB */ &&
                transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_LINEAR) {
            CGColorSpaceRef sRGBlinear = NULL;
            if (@available(macOS 10.12, iOS 10.0, tvOS 10.0, *)) {
                sRGBlinear = CGColorSpaceCreateWithName(kCGColorSpaceLinearSRGB);
            } else {
                sRGBlinear = CGColorSpaceCreateDeviceRGB();
            }
            colorSpace = sRGBlinear;
        }
        else if(colorPrimaries == AVIF_COLOR_PRIMARIES_BT2020 &&
                (transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_BT2020_10BIT ||
                 transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_BT2020_12BIT)) {
            CGColorSpaceRef bt2020 = NULL;
            if (@available(macOS 10.11, iOS 9.0, tvOS 9.0, *)) {
                bt2020 = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2020);
            } else {
                bt2020 = CGColorSpaceCreateDeviceRGB();
            }
            colorSpace = bt2020;
        }
        else if (colorPrimaries == AVIF_COLOR_PRIMARIES_BT2020 &&
                 transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_SMPTE2084) {
            CGColorSpaceRef bt2020pq = NULL;
            CFStringRef colorSpaceName = NULL;
            if (@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)) {
                colorSpaceName = kCGColorSpaceITUR_2100_PQ;
            } else if (@available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *)) {
                colorSpaceName = kCGColorSpaceITUR_2020_PQ;
            } else if (@available(macOS 10.14.6, iOS 12.6, tvOS 12.0, watchOS 5.0, *)) {
                colorSpaceName = kCGColorSpaceITUR_2020_PQ_EOTF;
            }
            if (colorSpaceName) {
                bt2020pq = CGColorSpaceCreateWithName(colorSpaceName);
            } else {
                bt2020pq = CGColorSpaceCreateDeviceRGB();
            }
            colorSpace = bt2020pq;
        } else if (colorPrimaries == AVIF_COLOR_PRIMARIES_BT2020 &&
                  transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_LINEAR) {
            static CGColorSpaceRef bt2020linear = NULL;
            if (@available(macOS 10.14.3, iOS 12.3, tvOS 12.3, *)) {
                bt2020linear = CGColorSpaceCreateWithName(kCGColorSpaceExtendedLinearITUR_2020);
            } else {
                bt2020linear = CGColorSpaceCreateDeviceRGB();
            }
            colorSpace = bt2020linear;
        } else if (colorPrimaries == AVIF_COLOR_PRIMARIES_SMPTE432 /* Display P3 */ &&
                transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_SRGB) {
            CGColorSpaceRef p3 = NULL;
            if (@available(macOS 10.11.2, iOS 9.3, tvOS 9.3, *)) {
                p3 = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
            } else {
                p3 = CGColorSpaceCreateDeviceRGB();
            }
            colorSpace = p3;
        } else if (colorPrimaries == AVIF_COLOR_PRIMARIES_SMPTE432 /* Display P3 */ &&
                transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_HLG) {
            CGColorSpaceRef p3hlg = NULL;
            if (@available(macOS 10.14.6, iOS 13.0, tvOS 13.0, *)) {
                p3hlg = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3_HLG);
            } else {
                p3hlg = CGColorSpaceCreateDeviceRGB();
            }
            colorSpace = p3hlg;
        }
        else if (colorPrimaries == AVIF_COLOR_PRIMARIES_SMPTE432 /* Display P3 */ &&
                transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_LINEAR) {
            CGColorSpaceRef p3linear = NULL;
            if (@available(macOS 10.14.3, iOS 12.3, tvOS 12.3, *)) {
                p3linear = CGColorSpaceCreateWithName(kCGColorSpaceExtendedLinearDisplayP3);
            } else {
                p3linear = CGColorSpaceCreateDeviceRGB();
            }
            colorSpace = p3linear;
        }
        else {
            colorSpace = CGColorSpaceCreateDeviceRGB();
        }
    }

    if (!colorSpace) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    int flags;
    if (isImageRequires64Bit) {
        flags = (int)kCGImageByteOrder16Little | (int)kCGImageAlphaLast | (int)kCGBitmapFloatComponents;
    } else {
        flags = (int)kCGBitmapByteOrder32Big | (int)kCGImageAlphaPremultipliedLast;
    }
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixelsData, stride*newHeight, AV1CGDataProviderReleaseDataCallback);
    if (!provider) {
        free(pixelsData);
        return NULL;
    }

    CGImageRef imageRef = CGImageCreate(newWidth, newHeight, depth, isImageRequires64Bit ? 64 : 32,
                                        newRowBytes, colorSpace, flags, provider, NULL, false, kCGRenderingIntentDefault);
    return imageRef;
}

- (nullable Image*)form:(nonnull avifDecoder*)decoder scale:(CGFloat)scale {
    auto imageRef = [self formCGImage:decoder scale:scale];
    Image *image = nil;
#if AVIF_PLUGIN_MAC
    image = [[NSImage alloc] initWithCGImage:imageRef size:CGSizeZero];
#else
    image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
#endif
    return image;
}

@end
