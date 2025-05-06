//
//  ColorSpace.m
//  avif
//
//  Created by Radzivon Bartoshyk on 03/05/2025.
//

#import <Foundation/Foundation.h>
#import "ColorSpace.h"
#if __has_include(<libavif/avif.h>)
#import <libavif/avif.h>
#else
#import "avif/avif.h"
#endif

@implementation ColorSpace

+(AvifColorSpace)queryColorSpace:(uint16_t)colorPrimaries transferCharacteristics:(uint16_t)transferCharacteristics {
    CGColorSpaceRef colorSpace = nullptr;
    bool wideGamut = false;
    
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
            wideGamut = true;
            bt2020 = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2020);
        } else {
            bt2020 = CGColorSpaceCreateDeviceRGB();
        }
        colorSpace = bt2020;
    } else if (colorPrimaries == AVIF_COLOR_PRIMARIES_BT2020 &&
               (transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_SMPTE2084
                || transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_HLG
                || transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_SMPTE428)) {
        if (transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_SMPTE2084) {
            wideGamut = true;
            colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2100_PQ);
        } else if (transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_HLG) {
            wideGamut = true;
            colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2100_HLG);
        } else {
            colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2020);
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
               (transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_SMPTE2084
                || transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_HLG
                || transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_SMPTE428)) {
        if (transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_SMPTE2084) {
            if (@available(iOS 13.4, *)) {
                wideGamut = true;
                colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3_PQ);
            }
        } else if (transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_HLG) {
            if (@available(iOS 13.4, *)) {
                wideGamut = true;
                colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3_HLG);
            }
        } else {
            colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
        }
    } else if (colorPrimaries == AVIF_COLOR_PRIMARIES_BT709 /* Rec 709 */ &&
               (transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_SMPTE2084
                || transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_HLG
                || transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_SMPTE428)) {
        if (transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_SMPTE2084) {
            if (@available(macOS 12.0, iOS 15.1, *)) {
                colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709_PQ);
            } else {
                colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
            }
        } else if (transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_HLG) {
            if (@available(macOS 12.0, iOS 15.1, *)) {
                colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709_HLG);
            } else {
                colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
            }
        } else {
            colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
        }
    } else if (colorPrimaries == AVIF_COLOR_PRIMARIES_SMPTE432 /* Display P3 */ &&
               transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_LINEAR) {
        CGColorSpaceRef p3linear = NULL;
        if (@available(macOS 10.14.3, iOS 12.3, tvOS 12.3, *)) {
            p3linear = CGColorSpaceCreateWithName(kCGColorSpaceExtendedLinearDisplayP3);
        } else {
            p3linear = CGColorSpaceCreateDeviceRGB();
        }
        colorSpace = p3linear;
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    if (!colorSpace) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    assert(colorSpace != nullptr);
    
    return AvifColorSpace {
        .mRef = colorSpace,
        .wideGamut = wideGamut
    };
}

+(void)apply:(avifImage*)image colorSpace:(EnclosedColorSpace)colorSpace {
    switch (colorSpace) {
        case kSRGB:
            image->colorPrimaries = AVIF_COLOR_PRIMARIES_SRGB;
            image->transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_SRGB;
            image->matrixCoefficients = AVIF_MATRIX_COEFFICIENTS_BT709;
            break;
        case kBt709PQ:
            image->colorPrimaries = AVIF_COLOR_PRIMARIES_BT709;
            image->transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_SMPTE2084;
            image->matrixCoefficients = AVIF_MATRIX_COEFFICIENTS_BT709;
            break;
        case kBt709HLG:
            image->colorPrimaries = AVIF_COLOR_PRIMARIES_BT709;
            image->transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_HLG;
            image->matrixCoefficients = AVIF_MATRIX_COEFFICIENTS_BT709;
            break;
        case kDisplayP3:
            image->colorPrimaries = AVIF_COLOR_PRIMARIES_SMPTE432;
            image->transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_SRGB;
            image->matrixCoefficients = AVIF_MATRIX_COEFFICIENTS_BT2020_NCL;
            break;
        case kDisplayP3PQ:
            image->colorPrimaries = AVIF_COLOR_PRIMARIES_SMPTE432;
            image->transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_SMPTE2084;
            image->matrixCoefficients = AVIF_MATRIX_COEFFICIENTS_BT2020_NCL;
            break;
        case kDisplayP3HLG:
            image->colorPrimaries = AVIF_COLOR_PRIMARIES_SMPTE432;
            image->transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_HLG;
            image->matrixCoefficients = AVIF_MATRIX_COEFFICIENTS_BT2020_NCL;
            break;
        case kBt2020:
            image->colorPrimaries = AVIF_COLOR_PRIMARIES_BT2020;
            image->transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_BT2020_10BIT;
            image->matrixCoefficients = AVIF_MATRIX_COEFFICIENTS_BT2020_NCL;
            break;
        case kBt2020PQ:
            image->colorPrimaries = AVIF_COLOR_PRIMARIES_BT2020;
            image->transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_SMPTE2084;
            image->matrixCoefficients = AVIF_MATRIX_COEFFICIENTS_BT2020_NCL;
            break;
        case kBt2020HLG:
            image->colorPrimaries = AVIF_COLOR_PRIMARIES_BT2020;
            image->transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_HLG;
            image->matrixCoefficients = AVIF_MATRIX_COEFFICIENTS_BT2020_NCL;
            break;
        default:
            break;
    }
}

@end
