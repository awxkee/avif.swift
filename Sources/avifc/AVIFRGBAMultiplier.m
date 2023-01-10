//
//  AVIFRGBAMultiplier.m
//
//  Created by Radzivon Bartoshyk on 27/05/2022.
//

#import <Foundation/Foundation.h>
#import "AVIFRGBAMultiplier.h"
#import <Accelerate/Accelerate.h>
#import <CoreGraphics/CoreGraphics.h>

@implementation AVIFRGBAMultiplier

+(nullable NSData*)premultiply:(nonnull NSData*)data width:(NSInteger)width height:(NSInteger)height depth:(NSInteger)depth {
    void* newBytes = [AVIFRGBAMultiplier premultiplyBytes:(unsigned char*)data.bytes width:width height:height depth:depth];
    if (!newBytes) {
        return nil;
    }
    NSData* returningData = [[NSData alloc] initWithBytesNoCopy:newBytes length:width*height*depth/2 deallocator:^(void * _Nonnull bytes, NSUInteger length) {
        free(bytes);
    }];
    return returningData;
}

+(nullable unsigned char*)premultiplyBytes:(nonnull unsigned char*)data width:(NSInteger)width height:(NSInteger)height depth:(NSInteger)depth {
    int multi = (int)depth / 2;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    vImage_Buffer src = {
        .data = (void*)(data),
        .width = width,
        .height = height,
        .rowBytes = width * multi
    };
    
    vImage_Buffer dest = {
        .data = malloc(width * height * multi),
        .width = width,
        .height = height,
        .rowBytes = width * multi
    };
    vImage_Error vEerror = vImagePremultiplyData_RGBA8888(&src, &dest, kvImageNoFlags);
    if (vEerror != kvImageNoError) {
        free(dest.data);
        CGColorSpaceRelease(colorSpace);
        return nil;
    }
    CGColorSpaceRelease(colorSpace);
    return (unsigned char*)(dest.data);
}

+(nullable unsigned char*)unpremultiplyBytes:(nonnull unsigned char*)data width:(NSInteger)width height:(NSInteger)height depth:(NSInteger)depth {
    int multi = (int)depth / 2;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    vImage_Buffer src = {
        .data = (void*)data,
        .width = width,
        .height = height,
        .rowBytes = width * multi
    };
    
    vImage_Buffer dest = {
        .data = malloc(width * height * multi),
        .width = width,
        .height = height,
        .rowBytes = width * multi
    };
    vImage_Error vEerror = vImageUnpremultiplyData_RGBA8888(&src, &dest, kvImageNoFlags);
    if (vEerror != kvImageNoError) {
        free(dest.data);
        CGColorSpaceRelease(colorSpace);
        return nil;
    }

    CGColorSpaceRelease(colorSpace);
    return (unsigned char*)(dest.data);
}

+(nullable NSData*)unpremultiply:(nonnull NSData*)data width:(NSInteger)width height:(NSInteger)height depth:(NSInteger)depth {
    int stride = (int)width * (depth > 8 ? sizeof(uint16_t) : sizeof(uint8_t));
    void* unpremultipliedBytes = [AVIFRGBAMultiplier unpremultiplyBytes:(unsigned char*)data.bytes width:width height:height depth:depth];
    if (!unpremultipliedBytes) {
        return nil;
    }
    NSData* returningData = [[NSData alloc] initWithBytesNoCopy:unpremultipliedBytes length:height*stride deallocator:^(void * _Nonnull bytes, NSUInteger length) {
        free(bytes);
    }];
    return returningData;
}
@end
