//
//  PlatformImage.mm
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
#import "PlatformImage.h"
#import <Accelerate/Accelerate.h>

@implementation EnclosedImage {
    std::vector<uint8_t> mData;
    EnclosedColorSpace mColorSpace;
    bool mSourceHasAlpha;
}

- (instancetype)init
{
    self = [super init];
    mColorSpace = EnclosedColorSpace::kSRGB;
    return self;
}

- (uint8_t *)data {
    return mData.data();
}

- (void)setLimits:(uint32_t)size {
    mData.resize(size);
}

-(void)setSourceAlpha:(bool)value {
    mSourceHasAlpha = value;
}

- (EnclosedColorSpace)colorSpace {
    return mColorSpace;
}

- (bool)sourceHasAlpha {
    return mSourceHasAlpha;
}

-(CGColorSpaceRef)recognizeColorSpace:(CGImageRef)imageRef {
    auto sourceRef = CGImageGetColorSpace(imageRef);
    NSString *colorSpaceName = (__bridge NSString *)CGColorSpaceCopyName(sourceRef);
    if (colorSpaceName == nullptr) {
        return CGColorSpaceCreateDeviceRGB();
    }
    
    if (@available(iOS 14.0, *)) {
        if (CFStringCompare((__bridge CFStringRef)colorSpaceName, kCGColorSpaceITUR_2100_HLG, 0) == kCFCompareEqualTo) {
            mColorSpace = EnclosedColorSpace::kBt2020HLG;
            return CGColorSpaceCreateWithName(kCGColorSpaceITUR_2100_HLG);
        }
    }
    if (@available(iOS 14.0, *)) {
        if (CFStringCompare((__bridge CFStringRef)colorSpaceName, kCGColorSpaceITUR_2100_PQ, 0) == kCFCompareEqualTo) {
            mColorSpace = EnclosedColorSpace::kBt2020PQ;
            return CGColorSpaceCreateWithName(kCGColorSpaceITUR_2100_PQ);
        }
    }
    
    if (CFStringCompare((__bridge CFStringRef)colorSpaceName, kCGColorSpaceITUR_2020, 0) == kCFCompareEqualTo) {
        mColorSpace = EnclosedColorSpace::kBt2020;
        return CGColorSpaceCreateWithName(kCGColorSpaceITUR_2020);
    }
    
    if (CFStringCompare((__bridge CFStringRef)colorSpaceName, kCGColorSpaceDisplayP3, 0) == kCFCompareEqualTo) {
        mColorSpace = EnclosedColorSpace::kDisplayP3;
        return CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
    }
    
    if (@available(iOS 13.4, *)) {
        if (CFStringCompare((__bridge CFStringRef)colorSpaceName, kCGColorSpaceDisplayP3_PQ, 0) == kCFCompareEqualTo) {
            mColorSpace = EnclosedColorSpace::kDisplayP3PQ;
            return CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3_PQ);
        }
    }
    
    if (CFStringCompare((__bridge CFStringRef)colorSpaceName, kCGColorSpaceDisplayP3_HLG, 0) == kCFCompareEqualTo) {
        mColorSpace = EnclosedColorSpace::kDisplayP3HLG;
        return CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3_HLG);
    }
    
    if (CFStringCompare((__bridge CFStringRef)colorSpaceName, kCGColorSpaceITUR_709, 0) == kCFCompareEqualTo) {
        mColorSpace = EnclosedColorSpace::kBt709;
        return CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
    }
    
    if (@available(iOS 15.1, *)) {
        if (CFStringCompare((__bridge CFStringRef)colorSpaceName, kCGColorSpaceITUR_709_PQ, 0) == kCFCompareEqualTo) {
            mColorSpace = EnclosedColorSpace::kBt709PQ;
            return CGColorSpaceCreateWithName(kCGColorSpaceITUR_709_PQ);
        }
    }
    
    if (@available(iOS 15.1, *)) {
        if (CFStringCompare((__bridge CFStringRef)colorSpaceName, kCGColorSpaceITUR_709_HLG, 0) == kCFCompareEqualTo) {
            mColorSpace = EnclosedColorSpace::kBt709HLG;
            return CGColorSpaceCreateWithName(kCGColorSpaceITUR_709_HLG);
        }
    }
    
    return CGColorSpaceCreateDeviceRGB();
}

@end

@implementation Image (ColorData)

-(bool)avifUnpremultiplyRGBA:(nonnull unsigned char*)data width:(NSInteger)width height:(NSInteger)height {
    vImage_Buffer src = {
        .data = (void*)data,
        .width = static_cast<vImagePixelCount>(width),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<vImagePixelCount>(width * 4)
    };

    vImage_Buffer dest = {
        .data = data,
        .width = static_cast<vImagePixelCount>(width),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<vImagePixelCount>(width * 4)
    };
    vImage_Error vEerror = vImageUnpremultiplyData_RGBA8888(&src, &dest, kvImageNoFlags);
    if (vEerror != kvImageNoError) {
        return false;
    }
    return true;
}

#if TARGET_OS_OSX

-(nullable CGImageRef)makeCGImage {
    CGImageRef imageRef = [self CGImageForProposedRect:nil context:nil hints:nil];
    return imageRef;
}

-(nullable EnclosedImage*)rgbaPixels:(nonnull uint32_t*)imageWidth imageHeight:(nonnull uint32_t*)imageHeight {
    CGImageRef imageRef = [self makeCGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    width = width % 2 == 0 ? width : width + 1;
    height = height % 2 == 0 ? height : height + 1;
    *imageWidth = static_cast<uint32_t>(width);
    *imageHeight = static_cast<uint32_t>(height);
    
    auto alphaInfo = CGImageGetAlphaInfo(imageRef);
    bool isRGBA = (alphaInfo == kCGImageAlphaPremultipliedLast ||
                   alphaInfo == kCGImageAlphaLast ||
                   alphaInfo == kCGImageAlphaPremultipliedFirst ||
                   alphaInfo == kCGImageAlphaFirst);
    
    uint32_t stride = (int)4 * (int)width * sizeof(uint8_t);
    
    auto img = [[EnclosedImage alloc] init];
    
    [img setLimits:static_cast<uint32_t>(stride) * static_cast<uint32_t>(height)];
    [img setSourceAlpha:isRGBA];

    CGColorSpaceRef colorSpace = [img recognizeColorSpace:imageRef];
    
    CGBitmapInfo bitmapInfo = (int)kCGImageAlphaPremultipliedLast | (int)kCGBitmapByteOrderDefault;

    CGContextRef targetContext = CGBitmapContextCreate(img.data, width, height, 8, stride, colorSpace, bitmapInfo);

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext: [NSGraphicsContext graphicsContextWithCGContext:targetContext flipped:FALSE]];

    [self drawInRect: NSMakeRect(0, 0, width, height)
            fromRect: NSZeroRect
           operation: NSCompositingOperationCopy
            fraction: 1.0];

    [NSGraphicsContext restoreGraphicsState];

    CGContextRelease(targetContext);
    CGColorSpaceRelease(colorSpace);

    if (![self avifUnpremultiplyRGBA:img.data width:width height:height]) {
        return nil;
    }

    return img;
}
#else
-(nullable EnclosedImage*)rgbaPixels:(nonnull uint32_t*)imageWidth imageHeight:(nonnull uint32_t*)imageHeight {
    CGImageRef imageRef = [self CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    width = width % 2 == 0 ? width : width + 1;
    height = height % 2 == 0 ? height : height + 1;
    *imageWidth = static_cast<uint32_t>(width);
    *imageHeight = static_cast<uint32_t>(height);
    
    uint32_t stride = (int)4 * (int)width * sizeof(uint8_t);
    
    auto alphaInfo = CGImageGetAlphaInfo(imageRef);
    bool isRGBA = (alphaInfo == kCGImageAlphaPremultipliedLast ||
                   alphaInfo == kCGImageAlphaLast ||
                   alphaInfo == kCGImageAlphaPremultipliedFirst ||
                   alphaInfo == kCGImageAlphaFirst);

    auto img = [[EnclosedImage alloc] init];
    
    [img setLimits:static_cast<uint32_t>(stride) * static_cast<uint32_t>(height)];
    [img setSourceAlpha:isRGBA];

    CGColorSpaceRef colorSpace = [img recognizeColorSpace:imageRef];
    
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(img.data, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 (int)kCGImageAlphaPremultipliedLast | (int)kCGBitmapByteOrderDefault);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);

    if (![self avifUnpremultiplyRGBA:img.data width:width height:height]) {
        return nil;
    }

    return img;
}
#endif
@end
