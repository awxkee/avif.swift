//
//  PlatformImage.m
//
//  Created by Radzivon Bartoshyk on 04/05/2022.
//

#import <Foundation/Foundation.h>
#import "PlatformImage.h"
#import "AVIFRGBAMultiplier.h"

@implementation Image (ColorData)

- (unsigned char *)rgbaPixels {
    CGImageRef imageRef = [self CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char*) calloc(height * width * 4, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    unsigned char* newBytes = [AVIFRGBAMultiplier unpremultiplyBytes:rawData width:width height:height depth:8];
    if (newBytes) {
        free(rawData);
        rawData = newBytes;
    }
    return rawData;
}

@end
