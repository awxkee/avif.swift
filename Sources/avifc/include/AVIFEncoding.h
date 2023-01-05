//
//  AVIFEncoding.h
//  
//
//  Created by Radzivon Bartoshyk on 01/05/2022.
//

#import "AVIFImageMacros.h"

#if AVIF_PLUGIN_MAC
#import <AppKit/AppKit.h>
#define Image   NSImage
#else
#import <UIKit/UIKit.h>
#define Image   UIImage
#endif

@interface AVIFEncoding : NSObject

- (nullable NSData *)encodeImage:(nonnull Image *)platformImage speed:(NSInteger)speed quality:(double)quality error:(NSError * _Nullable *_Nullable)error;

@end
