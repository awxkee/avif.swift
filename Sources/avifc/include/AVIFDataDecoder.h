//
//  AVIFDataDecoder.h
//  
//
//  Created by Radzivon Bartoshyk on 01/05/2022.
//

#import "AVIFImageMacros.h"
#import "AVIFEncoding.h"
#import "PlatformImage.h"
#if __has_include(<libavif/avif.h>)
#import <libavif/avif.h>
#else
#import "avif/avif.h"
#endif

@interface AVIFDataDecoder : NSObject

- (nullable Image *)incrementallyDecodeData:(nonnull NSData *)data;
- (nullable Image *)decode:(nonnull NSInputStream *)inputStream sampleSize:(CGSize)sampleSize maxContentSize:(NSUInteger)maxContentSize scale:(CGFloat)scale error:(NSError *_Nullable * _Nullable)error;
- (nullable NSValue*)readSize:(nonnull NSData*)data error:(NSError *_Nullable * _Nullable)error;
- (nullable NSValue*)readSizeFromPath:(nonnull NSString*)path error:(NSError *_Nullable * _Nullable)error;

@end
