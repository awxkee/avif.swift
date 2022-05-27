//
//  AVIFRGBAMultiplier.h
//
//  Created by Radzivon Bartoshyk on 01/05/2022.
//

#import "Foundation/Foundation.h"

@interface AVIFRGBAMultiplier: NSObject
+(nullable NSData*)premultiply:(nonnull NSData*)data width:(NSInteger)width height:(NSInteger)height depth:(NSInteger)depth;
+(nullable NSData*)unpremultiply:(nonnull NSData*)data width:(NSInteger)width height:(NSInteger)height depth:(NSInteger)depth;
+(nullable unsigned char*)premultiplyBytes:(nonnull unsigned char*)data width:(NSInteger)width height:(NSInteger)height depth:(NSInteger)depth;
+(nullable unsigned char*)unpremultiplyBytes:(nonnull unsigned char*)data width:(NSInteger)width height:(NSInteger)height depth:(NSInteger)depth;
@end
