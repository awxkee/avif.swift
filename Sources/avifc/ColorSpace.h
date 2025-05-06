//
//  Header.h
//  avif
//
//  Created by Radzivon Bartoshyk on 03/05/2025.
//

#ifndef ColorSpace_h
#define ColorSpace_h

#import "PlatformImage.h"
#if __has_include(<libavif/avif.h>)
#import <libavif/avif.h>
#else
#import "avif/avif.h"
#endif

struct AvifColorSpace {
    CGColorSpaceRef _Nonnull mRef;
    bool wideGamut;
};

@interface ColorSpace: NSObject
+(AvifColorSpace)queryColorSpace:(uint16_t)colorPrimaries transferCharacteristics:(uint16_t)transferCharacteristics;
+(void)apply:(nonnull avifImage*)image colorSpace:(EnclosedColorSpace)colorSpace;
@end


#endif /* ColorSpace_h */
