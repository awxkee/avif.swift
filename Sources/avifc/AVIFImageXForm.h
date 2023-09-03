//
//  AVIFImageXForm.h
//  
//
//  Created by Radzivon Bartoshyk on 02/09/2023.
//

#ifndef AVIFImageXForm_h
#define AVIFImageXForm_h

#import "PlatformImage.h"
#if __has_include(<libavif/avif.h>)
#import <libavif/avif.h>
#else
#import "avif/avif.h"
#endif

@interface AVIFImageXForm : NSObject
- (nullable Image*)form:(nonnull avifDecoder*)decoder scale:(CGFloat)scale;
- (_Nullable CGImageRef)formCGImage:(nonnull avifDecoder*)decoder scale:(CGFloat)scale;
@end


#endif /* Header_h */
