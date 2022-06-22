//
//  AVIFAnimatedEncoder.h
//  Document Scanner
//
//  Created by Radzivon Bartoshyk on 04/05/2022.
//

#ifndef AVIFAnimatedEncoder_h
#define AVIFAnimatedEncoder_h

#include "PlatformImage.h"

@interface AVIFAnimatedEncoder : NSObject
- (void)create;
- (void* _Nullable)addImage:(Image * _Nonnull)platformImage duration:(NSUInteger)timescale error:(NSError * _Nullable * _Nullable)error;
- (NSData* _Nullable)encode:(NSError * _Nullable *_Nullable)error;
- (void)setSpeed:(NSInteger)speed;
- (void)setCompressionQuality:(double)quality;
- (void)cleanUp;
@end


#endif /* AVIFAnimatedEncoder_h */
