//
//  AVIFDataDecoder.h
//  
//
//  Created by Radzivon Bartoshyk on 01/05/2022.
//

#import "AVIFImageMacros.h"
#import "AVIFEncoding.h"
#import "PlatformImage.h"

@interface AVIFDataDecoder : NSObject

- (nullable Image *)incrementallyDecodeData:(nonnull NSData *)data;
- (nullable Image *)decode:(nonnull NSInputStream *)inputStream sampleSize:(CGSize)sampleSize maxContentSize:(NSUInteger)maxContentSize error:(NSError *_Nullable * _Nullable)error;
- (nullable NSValue*)readSize:(nonnull NSData*)data error:(NSError *_Nullable * _Nullable)error;
- (nullable NSValue*)readSizeFromPath:(nonnull NSString*)path error:(NSError *_Nullable * _Nullable)error;

@end
