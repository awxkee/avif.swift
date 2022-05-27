//
//  PlatformImage.h
//
//  Created by Radzivon Bartoshyk on 04/05/2022.
//

#ifndef PlatformImage_h
#define PlatformImage_h

#if AVIF_PLUGIN_MAC
#import <AppKit/AppKit.h>
#define Image   NSImage
#else
#import <UIKit/UIKit.h>
#define Image   UIImage
#endif

@interface Image (ColorData)
- (unsigned char *)rgbaPixels;
@end


#endif /* PlatformImage_h */
