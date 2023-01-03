//
//  PlatformImage.h
//
//  Created by Radzivon Bartoshyk on 04/05/2022.
//

#ifndef PlatformImage_h
#define PlatformImage_h

#import "TargetConditionals.h"

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#define Image   NSImage
#else
#import <UIKit/UIKit.h>
#define Image   UIImage
#endif

static void AV1CGDataProviderReleaseDataCallback(void *info, const void *data, size_t size) {
    if (data) free((void*)data);
}

@interface Image (ColorData)
- (unsigned char *)rgbaPixels;
@end


#endif /* PlatformImage_h */
