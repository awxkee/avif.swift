//
//  AVIFAnimatedDecoder.h
//  
//
//  Created by Radzivon Bartoshyk on 22/06/2022.
//

#import <Foundation/Foundation.h>
#import "PlatformImage.h"

@interface AVIFAnimatedDecoder : NSObject
-(nullable id)initWithData:(nonnull NSData*)data;
-(nullable CGImageRef)get:(int)frame;
-(nullable UIImage*)getImage:(int)frame;
-(int)framesCount;
-(int)frameDuration:(int)frame;
-(CGSize)imageSize;
-(int)duration;
@end
