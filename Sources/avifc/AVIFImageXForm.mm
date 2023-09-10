//
//  AVIFImageXForm.mm
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 02/09/2022.
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
#import "AVIFImageXForm.h"
#import <vector>
#import <Accelerate/Accelerate.h>
#import <CoreGraphics/CoreGraphics.h>
#import "PerceptualQuantinizer.h"
#import "TargetConditionals.h"
#import "Rgb1010102Converter.h"
#import "RgbTransfer.h"

@implementation AVIFImageXForm

+(bool)RGBA8toF16:(nonnull uint8_t*)data dst:(nonnull uint8_t*)dst stride:(int)stride width:(int)width height:(int)height {
    int newStride = width * sizeof(uint16_t) * 4;

    vImage_Buffer srcBuffer = {
        .data = (void*)data,
        .width = static_cast<vImagePixelCount>(width * 4),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<size_t>(stride)
    };

    vImage_Buffer dstBuffer = {
        .data = dst,
        .width = static_cast<vImagePixelCount>(width * 4),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<size_t>(newStride)
    };
    vImage_Error vEerror = vImageConvert_Planar8toPlanar16F(&srcBuffer, &dstBuffer, kvImageNoFlags);
    if (vEerror != kvImageNoError) {
        return false;
    }
    return true;
}

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
    int depth = decoder->image->depth == 10 ? 10 : (decoder->image->depth > 8 ? 16 : 8);
    int stride = rgbImage.rowBytes;
    auto pixelsData = reinterpret_cast<unsigned char*>(malloc(stride * newHeight));

    if (![RgbTransfer CopyBuffer:rgbImage.pixels dst:pixelsData stride:stride width:newWidth height:newHeight pixelSize:isImageRequires64Bit ? sizeof(uint16_t) : sizeof(uint8_t)]) {
        avifRGBImageFreePixels(&rgbImage);
        free(pixelsData);
        return nil;
    }

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
            // Almost no reason to use 8-bit for PQ
            if (depth == 8) {
                int newStride = newWidth * sizeof(uint16_t) * 4;
                uint8_t* rgba16Buffer = reinterpret_cast<uint8_t*>(malloc(newHeight * newStride));
                if (![AVIFImageXForm RGBA8toF16:pixelsData dst:rgba16Buffer stride:stride width:newWidth height:newHeight]) {
                    free(rgba16Buffer);
                } else {
                    free(pixelsData);
                    pixelsData = rgba16Buffer;
                    stride = newStride;
                    depth = 10;
                }
            }
            [PerceptualQuantinizer transfer:reinterpret_cast<uint8_t*>(pixelsData)
                                     stride:stride width:newWidth height:newHeight U16:depth > 8 depth:depth half:depth > 8];
            if (depth > 8 && depth != 10) {
                if (@available(iOS 14.0, *)) {
                    colorSpace = CGColorSpaceCreateExtendedLinearized(CGColorSpaceCreateWithName(kCGColorSpaceExtendedITUR_2020));
                } else {
                    colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2020);
                }
            } else {
                if (@available(iOS 14.0, *)) {
                    colorSpace = CGColorSpaceCreateLinearized(CGColorSpaceCreateWithName(kCGColorSpaceITUR_2020));
                } else {
                    colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2020);
                }
            }
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
    if (depth == 10) {
        flags = (int)kCGBitmapByteOrder32Big | (int)kCGImagePixelFormatRGB101010 | (int)kCGImageAlphaLast;
        uint8_t* rgb1010102Buffer = reinterpret_cast<uint8_t*>(malloc(newWidth * 4 * sizeof(uint8_t) * newHeight));
        if (![Rgb1010102Converter F16ToRGBA1010102:pixelsData dst:rgb1010102Buffer stride:&stride width:newWidth height:newHeight]) {
            free(pixelsData);
            return NULL;
        }
        free(pixelsData);
        pixelsData = rgb1010102Buffer;
    } else {
        if (isImageRequires64Bit) {
            flags = (int)kCGImageByteOrder16Little | (int)kCGImageAlphaLast | (int)kCGBitmapFloatComponents;
        } else {
            flags = (int)kCGBitmapByteOrder32Big | (int)kCGImageAlphaPremultipliedLast;
        }
    }
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixelsData, stride*newHeight, AV1CGDataProviderReleaseDataCallback);
    if (!provider) {
        free(pixelsData);
        return NULL;
    }

    CGImageRef imageRef = CGImageCreate(newWidth, newHeight, depth, (depth == 10 || depth == 8) ? 32 : 64,
                                        stride, colorSpace, flags, provider, NULL, false, kCGRenderingIntentDefault);
    return imageRef;
}

- (nullable Image*)form:(nonnull avifDecoder*)decoder scale:(CGFloat)scale {
    auto imageRef = [self formCGImage:decoder scale:scale];
    Image *image = nil;
#if TARGET_OS_OSX
    image = [[NSImage alloc] initWithCGImage:imageRef size:CGSizeZero];
#else
    image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
#endif
    return image;
}

@end
