//
//  AVIFEncoding.mm
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 01/05/2022.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <Foundation/Foundation.h>
#if __has_include(<libavif/avif.h>)
#import <libavif/avif.h>
#else
#import "avif/avif.h"
#endif
#import <Accelerate/Accelerate.h>
#include "AVIFEncoding.h"
#include "PlatformImage.h"
#include <vector>
#include <sys/types.h>
#include <sys/sysctl.h>
#import "ColorSpace.h"
#import "avifpixart.h"

static void releaseSharedEncoder(avifEncoder* encoder) {
    avifEncoderDestroy(encoder);
}

static void releaseSharedEncoderImage(avifImage* image) {
    avifImageDestroy(image);
}

static void releaseSharedPixels(unsigned char * pixels) {
    free(pixels);
}

@implementation AVIFEncoding {
}

- (nullable NSData *)encodeImage:(nonnull Image *)platformImage
                           speed:(NSInteger)speed
                         quality:(double)quality
                    highСontrast:(bool)highСontrast
                  preferredCodec:(PreferredCodec)preferredCodec
                           error:(NSError * _Nullable *_Nullable)error {
    uint32_t width;
    uint32_t height;
    
    auto sourceImage = [platformImage rgbaPixels:&width imageHeight:&height];
    if (!sourceImage) {
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder"
                                            code:500
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Fetching image pixels has failed" }];
        return nil;
    }
 
    auto img = avifImageCreate(width, height, (uint32_t)8, highСontrast ? AVIF_PIXEL_FORMAT_YUV422 : AVIF_PIXEL_FORMAT_YUV420);

    if (!img) {
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder"
                                            code:500
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Memory allocation for image has failed" }];
        return nil;
    }
    std::shared_ptr<avifImage> image(img, releaseSharedEncoderImage);

    avifCodecChoice choice = AVIF_CODEC_CHOICE_AUTO;

    switch (preferredCodec) {
        case kAOM:
            {
                choice = avifCodecChoiceFromName("aom");
            }
            break;
        case kSVTAV1:
            {
                choice = avifCodecChoiceFromName("svt");
            }
            break;
    }
    
    if (sourceImage.sourceHasAlpha) {
        if (avifImageAllocatePlanes(image.get(), AVIF_PLANES_ALL) != AVIF_RESULT_OK) {
            *error = [[NSError alloc] initWithDomain:@"AVIFEncoder"
                                                code:500
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Memory allocation for image has failed" }];
            return nil;
        }
    } else {
        if (avifImageAllocatePlanes(image.get(), AVIF_PLANES_YUV) != AVIF_RESULT_OK) {
            *error = [[NSError alloc] initWithDomain:@"AVIFEncoder"
                                                code:500
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Memory allocation for image has failed" }];
            return nil;
        }
    }
    
    [ColorSpace apply:image.get() colorSpace: [sourceImage colorSpace]];
        
    YuvMatrix matrix = YuvMatrix::Bt709;
    
    if (image->matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_BT2020_NCL) {
        matrix = YuvMatrix::Bt2020;
    }
    
    if (highСontrast) {
        image->yuvRange = AVIF_RANGE_FULL;
        pixart_rgba8_to_yuv8(image->yuvPlanes[0], image->yuvRowBytes[0],
                             image->yuvPlanes[1], image->yuvRowBytes[1],
                             image->yuvPlanes[2], image->yuvRowBytes[2],
                             [sourceImage data], width * 4,
                             width, height,
                             YuvRange::Pc, matrix, YuvType::Yuv422);
    } else {
        pixart_rgba8_to_yuv8(image->yuvPlanes[0], image->yuvRowBytes[0],
                             image->yuvPlanes[1], image->yuvRowBytes[1],
                             image->yuvPlanes[2], image->yuvRowBytes[2],
                             [sourceImage data], width * 4,
                             width, height,
                             YuvRange::Tv, matrix, YuvType::Yuv420);
    }

    if (sourceImage.sourceHasAlpha && image->alphaPlane) {
        if (image->depth > 8) {
            uint32_t expand = image->depth - 8;
            uint32_t rem = 8 - expand;
            for (uint32_t y = 0; y < height; ++y) {
                auto srcPtr = sourceImage.data + y * width * 4;
                auto dstPtr = reinterpret_cast<uint16_t*>(image->alphaPlane + image->alphaRowBytes * y);
                for (uint32_t x = 0; x < width; ++x) {
                    uint32_t oldAlpha = static_cast<uint32_t>(srcPtr[3]);
                    uint32_t newAlpha = (oldAlpha << expand) | (oldAlpha >> rem);
                    *dstPtr = newAlpha;
                    dstPtr += 1;
                    srcPtr += 4;
                }
            }
        } else {
            for (uint32_t y = 0; y < height; ++y) {
                auto srcPtr = sourceImage.data + y * width * 4;
                auto dstPtr = image->alphaPlane + image->alphaRowBytes * y;
                for (uint32_t x = 0; x < width; ++x) {
                    *dstPtr = srcPtr[3];
                    dstPtr += 1;
                    srcPtr += 4;
                }
            }
        }
    }
        
    std::time_t currentTime = std::time(nullptr);
    std::tm* timeInfo = std::localtime(&currentTime);
    
    char formattedTime[66];
    std::strftime(formattedTime, sizeof(formattedTime), "%Y:%m:%d %H:%M:%S", timeInfo);
    std::string dateTime(formattedTime);
    
    std::string xmpMetadata = "<?xpacket begin='﻿' id='W5M0MpCehiHzreSzNTczkc9d'?>"
    "<x:xmpmeta xmlns:x='adobe:ns:meta/' x:xmptk='XMP Core 5.5.0'>"
    "<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>"
    "<rdf:Description rdf:about='' xmlns:dc='http://purl.org/dc/elements/1.1/'>"
    "<dc:title>Generated image by avif.swift</dc:title>"
    "<dc:creator>avif.swift</dc:creator>"
    "<dc:description>A image was created by avif.swift (https://github.com/awxkee/avif.swift)</dc:description>"
    "<dc:date>" + dateTime + "</dc:date>\n"
    "<dc:publisher>https://github.com/awxkee/avif.swift</dc:publisher>"
    "<dc:format>AVIF</dc:format>"
    "</rdf:Description>"
    "<rdf:Description rdf:about='' xmlns:exif='http://ns.adobe.com/exif/1.0/'>\n"
    "<exif:ColorSpace>sRGB</exif:ColorSpace>\n"
    "<exif:ColorProfile>sRGB IEC61966-2.1</exif:ColorProfile>\n"
    "</rdf:Description>\n"
    "<rdf:Description rdf:about='' xmlns:xmp='http://ns.adobe.com/xap/1.0/'>\n"
    "<xmp:CreatorTool>avif.swift (https://github.com/awxkee/avif.swift)</xmp:CreatorTool>\n"
    "<xmp:ModifyDate>" + dateTime + "</xmp:ModifyDate>\n"
    "</rdf:Description>\n"
    "</rdf:RDF>"
    "</x:xmpmeta>"
    "<?xpacket end='w'?>";
    
    auto exifResult = avifImageSetMetadataXMP(image.get(), reinterpret_cast<const uint8_t*>(xmpMetadata.data()), xmpMetadata.size());
    if (exifResult != AVIF_RESULT_OK) {
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Add EXIF failed with result: %s", avifResultToString(exifResult)] }];
        return nil;
    }
    
    auto enc = avifEncoderCreate();
    if (!enc) {
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder"
                                            code:500
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Memory allocation for encoder has failed" }];
        return nil;
    }
    std::shared_ptr<avifEncoder> encoder(enc, releaseSharedEncoder);
    encoder->maxThreads = 6;
    encoder->quality = quality*100;
    encoder->codecChoice = choice;
    if (speed != -1) {
        encoder->speed = (int)MAX(MIN(speed, AVIF_SPEED_FASTEST), AVIF_SPEED_SLOWEST);
    }
    avifResult addImageResult = avifEncoderAddImage(encoder.get(), image.get(), 1, AVIF_ADD_IMAGE_FLAG_SINGLE);
    if (addImageResult != AVIF_RESULT_OK) {
        encoder.reset();
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"add image failed with result: %s", avifResultToString(addImageResult)] }];
        return nil;
    }
    
    avifRWData avifOutput = AVIF_DATA_EMPTY;
    avifResult finishResult = avifEncoderFinish(encoder.get(), &avifOutput);
    if (finishResult != AVIF_RESULT_OK) {
        encoder.reset();
        *error = [[NSError alloc] initWithDomain:@"AVIFEncoder" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"encoding failed with result: %s", avifResultToString(addImageResult)] }];
        return nil;
    }
    
    NSData *result = [[NSData alloc] initWithBytes:avifOutput.data length:avifOutput.size];
    
    avifRWDataFree(&avifOutput);
    encoder.reset();
    
    return result;
}

@end
