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
    int targetBytesPerRow = ((4 * (int)width) + 31) & (~31);
    uint8_t *targetMemory = malloc((int)(targetBytesPerRow * height));

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host;

    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, width, height, 8, targetBytesPerRow, colorSpace, bitmapInfo);

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext: [NSGraphicsContext graphicsContextWithCGContext:targetContext flipped:FALSE]];
    CGColorSpaceRelease(colorSpace);

    [self drawInRect: NSMakeRect(0, 0, width, height)
            fromRect: NSZeroRect
           operation: NSCompositingOperationCopy
            fraction: 1.0];

    [NSGraphicsContext restoreGraphicsState];

    int bufferBytesPerRow = ((3 * (int)width) + 31) & (~31);
    uint8_t *buffer = malloc(bufferBytesPerRow * height);

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            uint32_t *color = ((uint32_t *)&targetMemory[y * targetBytesPerRow + x * 4]);

            uint32_t r = ((*color >> 16) & 0xff);
            uint32_t g = ((*color >> 8) & 0xff);
            uint32_t b = (*color & 0xff);

            buffer[y * bufferBytesPerRow + x * 3 + 0] = r;
            buffer[y * bufferBytesPerRow + x * 3 + 1] = g;
            buffer[y * bufferBytesPerRow + x * 3 + 2] = b;
        }
    }

    CGContextRelease(targetContext);

    free(targetMemory);

    return buffer;
}
#else
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
#endif
@end
