//
//  PlatformImage.m
//
//  Created by Radzivon Bartoshyk on 04/05/2022.
//

#import <Foundation/Foundation.h>
#import "PlatformImage.h"
#import "AVIFRGBAMultiplier.h"

@implementation Image (ColorData)
#if TARGET_OS_OSX

-(nullable CGImageRef)makeCGImage {
    NSRect rect = NSMakeRect(0, 0, self.size.width, self.size.height);
    CGImageRef imageRef = [self CGImageForProposedRect: &rect context:nil hints:nil];
    return imageRef;
}

-(nonnull uint8_t *) rgbaPixels {
    CGImageRef imageRef = [self makeCGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    int stride = (int)4 * (int)width * sizeof(uint8_t);
    uint8_t *targetMemory = reinterpret_cast<uint8_t*>(malloc((int)(stride * height)));

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;

    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, width, height, 8, stride, colorSpace, bitmapInfo);

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext: [NSGraphicsContext graphicsContextWithCGContext:targetContext flipped:FALSE]];
    CGColorSpaceRelease(colorSpace);

    [self drawInRect: NSMakeRect(0, 0, width, height)
            fromRect: NSZeroRect
           operation: NSCompositingOperationCopy
            fraction: 1.0];

    [NSGraphicsContext restoreGraphicsState];

    CGContextRelease(targetContext);

    return targetMemory;
}
#else
- (unsigned char *)rgbaPixels {
    CGImageRef imageRef = [self CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char*) malloc(height * width * 4 * sizeof(uint8_t));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);

    return rawData;
}
#endif
@end
