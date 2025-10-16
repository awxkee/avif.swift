//
//  AVIFImageXForm.mm
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 02/09/2022.
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
#import "AVIFImageXForm.h"
#import <vector>
#import <Accelerate/Accelerate.h>
#import <CoreGraphics/CoreGraphics.h>
#import "TargetConditionals.h"
#import "RgbTransfer.h"
#import <avif/internal.h>
#import "ColorSpace.h"
#import "avifpixart.h"

using namespace std;

class XFormDataContainer {
public:
    XFormDataContainer(vector<uint8_t>& src): container(src) {
        
    }
    
    void clear() {
        container.clear();
    }
    
    uint8_t* data() {
        return container.data();
    }
private:
    vector<uint8_t> container;
};

static void XFormDataRelease(void * _Nullable info, const void * _Nullable data, size_t size) {
    XFormDataContainer* mDataContainer = reinterpret_cast<XFormDataContainer*>(info);
    if (mDataContainer) {
        mDataContainer->clear();
        delete mDataContainer;
    }
}

struct AvifImageHandle {
    std::vector<uint8_t> data;
    uint32_t stride;
    uint32_t width;
    uint32_t height;
    uint32_t bitDepth;
    uint32_t components;
};

#define AVIF_CHECK_RGB_PLANES_OR_RETURN(imagePtr, resultPtr)                 \
if ((imagePtr)->yuvPlanes[0] == nullptr ||                           \
(imagePtr)->yuvPlanes[1] == nullptr ||                           \
(imagePtr)->yuvPlanes[2] == nullptr) {                           \
*(resultPtr) = AVIF_RESULT_UNKNOWN_ERROR;                        \
return AvifImageHandle {                                         \
.data = std::vector<uint8_t>(),                              \
.stride = 0,                                                 \
.width = 0,                                                  \
.height = 0,                                                 \
.bitDepth = 0,                                               \
.components = 0                                              \
};                                                               \
}                                                                    \

#define AVIF_CHECK_RGBA_PLANES_OR_RETURN(imagePtr, resultPtr)                 \
if ((imagePtr)->yuvPlanes[0] == nullptr ||                           \
(imagePtr)->yuvPlanes[1] == nullptr ||                           \
(imagePtr)->yuvPlanes[2] == nullptr ||                           \
(imagePtr)->alphaPlane == nullptr) {                             \
*(resultPtr) = AVIF_RESULT_UNKNOWN_ERROR;                        \
return AvifImageHandle {                                         \
.data = std::vector<uint8_t>(),                              \
.stride = 0,                                                 \
.width = 0,                                                  \
.height = 0,                                                 \
.bitDepth = 0,                                               \
.components = 0                                              \
};                                                               \
}                                                                    \


#define AVIF_CHECK_NOT_YUV400_OR_RETURN(imagePtr, resultPtr)                 \
if (image->yuvFormat == AVIF_PIXEL_FORMAT_YUV400) {                  \
*(resultPtr) = AVIF_RESULT_UNKNOWN_ERROR;                        \
return AvifImageHandle {                                         \
.data = std::vector<uint8_t>(),                              \
.stride = 0,                                                 \
.width = 0,                                                  \
.height = 0,                                                 \
.bitDepth = 0,                                               \
.components = 0                                              \
};                                                               \
}                                                                    \

#define RETURN_ERROR_HANDLE(result_ptr)                     \
*(result_ptr) = AVIF_RESULT_UNKNOWN_ERROR;          \
return AvifImageHandle {                            \
.data = std::vector<uint8_t>(),                 \
.stride = 0,                                    \
.width = 0,                                     \
.height = 0,                                    \
.bitDepth = 0,                                  \
.components = 0                                 \
};                                              \

@implementation AVIFImageXForm

+(AvifImageHandle)handleImage:(nonnull avifImage*)image result:(int*)result {
    if (image == nullptr) {
        RETURN_ERROR_HANDLE(result);
    }
    auto imageUsesAlpha = image->imageOwnsAlphaPlane || image->alphaPlane != nullptr;
    
    *result = AVIF_RESULT_OK;
    
    uint32_t components = imageUsesAlpha ? 4 : 3;
    avifMatrixCoefficients matrixCoefficients = image->matrixCoefficients;
    avifRange avifYuvRange = image->yuvRange;
    YuvRange pixartYuvRange = YuvRange::Pc;
    if (avifYuvRange == AVIF_RANGE_LIMITED) {
        pixartYuvRange = YuvRange::Tv;
    }
    
    bool highBitDepth = image->depth > 8;
    
    YuvType yuvType = YuvType::Yuv420;
    
    if (image->yuvFormat == AVIF_PIXEL_FORMAT_YUV422) {
        yuvType = YuvType::Yuv422;
    } else if (image->yuvFormat == AVIF_PIXEL_FORMAT_YUV444) {
        yuvType = YuvType::Yuv444;
    }
    
    if ((matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_YCGCO_RE
         || matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_YCGCO_RO)
        && image->depth == 10) {
        if (components == 3) {
            AVIF_CHECK_RGB_PLANES_OR_RETURN(image, result);
            AVIF_CHECK_NOT_YUV400_OR_RETURN(image, result);
            uint32_t stride = image->width * 3;
            std::vector<uint8_t> data(stride * image->height);
            AvifYCgCoRType rType = AvifYCgCoRType::Re;
            if (matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_YCGCO_RO) {
                rType = AvifYCgCoRType::Ro;
            }
            pixart_icgc_r_type_to_rgb(reinterpret_cast<const uint16_t*>(image->yuvPlanes[0]), image->yuvRowBytes[0],
                                      reinterpret_cast<const uint16_t*>(image->yuvPlanes[1]), image->yuvRowBytes[1],
                                      reinterpret_cast<const uint16_t*>(image->yuvPlanes[2]), image->yuvRowBytes[2],
                                      data.data(), stride,
                                      image->width, image->height,
                                      pixartYuvRange, rType, yuvType);
            
            return AvifImageHandle {
                .data = data,
                .stride = stride,
                .width = image->width,
                .height = image->height,
                .bitDepth = 8,
                .components = 3
            };
        } else if (components == 4) {
            AVIF_CHECK_RGBA_PLANES_OR_RETURN(image, result);
            AVIF_CHECK_NOT_YUV400_OR_RETURN(image, result);
            uint32_t stride = image->width * 4;
            std::vector<uint8_t> data(stride * image->height);
            AvifYCgCoRType rType = AvifYCgCoRType::Re;
            if (matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_YCGCO_RO) {
                rType = AvifYCgCoRType::Ro;
            }
            pixart_icgc_r_type_with_alpha_to_rgba(reinterpret_cast<const uint16_t*>(image->yuvPlanes[0]), image->yuvRowBytes[0],
                                                  reinterpret_cast<const uint16_t*>(image->yuvPlanes[1]), image->yuvRowBytes[1],
                                                  reinterpret_cast<const uint16_t*>(image->yuvPlanes[2]), image->yuvRowBytes[2],
                                                  reinterpret_cast<const uint16_t*>(image->alphaPlane), image->alphaRowBytes,
                                                  data.data(), stride,
                                                  image->width, image->height,
                                                  pixartYuvRange, rType, yuvType);
            return AvifImageHandle {
                .data = data,
                .stride = stride,
                .width = image->width,
                .height = image->height,
                .bitDepth = 8,
                .components = 4
            };
        } else {
            RETURN_ERROR_HANDLE(result);
        }
    }
    
    YuvMatrix matrix = YuvMatrix::Bt709;
    if (image->matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_BT601) {
        matrix = YuvMatrix::Bt601;
    } else if (image->matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_BT2020_NCL
               || image->matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_SMPTE2085) {
        matrix = YuvMatrix::Bt2020;
    } else if (image->matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_IDENTITY) {
        matrix = YuvMatrix::Identity;
        if (image->yuvFormat != AVIF_PIXEL_FORMAT_YUV444) {
            RETURN_ERROR_HANDLE(result);
        }
    } else if (image->matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_YCGCO) {
        matrix = YuvMatrix::YCgCo;
    }
    
    uint32_t bitDepth = image->depth;
    
    if (image->yuvFormat == AVIF_PIXEL_FORMAT_YUV400) {
        if (image->yuvPlanes[0] == nullptr) {
            RETURN_ERROR_HANDLE(result);
        }
        if (highBitDepth) {
            if (components == 3) {
                uint32_t stride = image->width * 3 * sizeof(uint16_t);
                std::vector<uint8_t> data(stride * image->height);
                pixart_yuv400_p16_to_rgb16(reinterpret_cast<const uint16_t*>(image->yuvPlanes[0]), image->yuvRowBytes[0],
                                           reinterpret_cast<uint16_t*>(data.data()), stride,
                                           bitDepth,
                                           image->width, image->height,
                                           pixartYuvRange, matrix);
                return AvifImageHandle {
                    .data = data,
                    .stride = stride,
                    .width = image->width,
                    .height = image->height,
                    .bitDepth = bitDepth,
                    .components = 3
                };
            } else if (components == 4) {
                if (image->alphaPlane == nullptr) {
                    RETURN_ERROR_HANDLE(result);
                }
                uint32_t stride = image->width * 4;
                std::vector<uint8_t> data(stride * image->height);
                pixart_yuv400_p16_with_alpha_to_rgba16(reinterpret_cast<const uint16_t*>(image->yuvPlanes[0]), image->yuvRowBytes[0],
                                                       reinterpret_cast<const uint16_t*>(image->alphaPlane), image->alphaRowBytes,
                                                       reinterpret_cast<uint16_t*>(data.data()), stride,
                                                       bitDepth,
                                                       image->width, image->height,
                                                       pixartYuvRange, matrix);
                return AvifImageHandle {
                    .data = data,
                    .stride = stride,
                    .width = image->width,
                    .height = image->height,
                    .bitDepth = bitDepth,
                    .components = 4
                };
            }
        } else {
            if (components == 3) {
                uint32_t stride = image->width * 3;
                std::vector<uint8_t> data(stride * image->height);
                pixart_yuv400_to_rgb8(image->yuvPlanes[0], image->yuvRowBytes[0],
                                      data.data(), stride,
                                      image->width, image->height,
                                      pixartYuvRange, matrix);
                return AvifImageHandle {
                    .data = data,
                    .stride = stride,
                    .width = image->width,
                    .height = image->height,
                    .bitDepth = 8,
                    .components = 3
                };
            } else if (components == 4) {
                if (image->alphaPlane == nullptr) {
                    RETURN_ERROR_HANDLE(result);
                }
                uint32_t stride = image->width * 4;
                std::vector<uint8_t> data(stride * image->height);
                pixart_yuv400_with_alpha_to_rgba8(image->yuvPlanes[0], image->yuvRowBytes[0],
                                                  image->alphaPlane, image->alphaRowBytes,
                                                  data.data(), stride,
                                                  image->width, image->height,
                                                  pixartYuvRange, matrix);
                return AvifImageHandle {
                    .data = data,
                    .stride = stride,
                    .width = image->width,
                    .height = image->height,
                    .bitDepth = 8,
                    .components = 4
                };
            }
        }
    }
    
    if (matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_YCGCO_RE
        || matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_YCGCO_RO) {
        if (image->depth == 12) {
            if (components == 3) {
                AVIF_CHECK_RGB_PLANES_OR_RETURN(image, result);
                AVIF_CHECK_NOT_YUV400_OR_RETURN(image, result);
                uint32_t stride = image->width * 3 * sizeof(uint16_t);
                std::vector<uint8_t> data(stride * image->height);
                AvifYCgCoRType rType = AvifYCgCoRType::Re;
                if (matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_YCGCO_RO) {
                    rType = AvifYCgCoRType::Ro;
                }
                bitDepth = 10;
                pixart_icgc12_r_to_rgb10(reinterpret_cast<const uint16_t*>(image->yuvPlanes[0]), image->yuvRowBytes[0],
                                         reinterpret_cast<const uint16_t*>(image->yuvPlanes[1]), image->yuvRowBytes[1],
                                         reinterpret_cast<const uint16_t*>(image->yuvPlanes[2]), image->yuvRowBytes[2],
                                         reinterpret_cast<uint16_t*>(data.data()), stride,
                                         image->width, image->height,
                                         pixartYuvRange, rType, yuvType);
                
                return AvifImageHandle {
                    .data = data,
                    .stride = stride,
                    .width = image->width,
                    .height = image->height,
                    .bitDepth = 8,
                    .components = 3
                };
            } else if (components == 4) {
                AVIF_CHECK_RGBA_PLANES_OR_RETURN(image, result);
                AVIF_CHECK_NOT_YUV400_OR_RETURN(image, result);
                uint32_t stride = image->width * 4 * sizeof(uint16_t);
                std::vector<uint8_t> data(stride * image->height);
                AvifYCgCoRType rType = AvifYCgCoRType::Re;
                if (matrixCoefficients == AVIF_MATRIX_COEFFICIENTS_YCGCO_RO) {
                    rType = AvifYCgCoRType::Ro;
                }
                bitDepth = 10;
                pixart_icgc_r_alpha12_to_rgba10(reinterpret_cast<const uint16_t*>(image->yuvPlanes[0]), image->yuvRowBytes[0],
                                                reinterpret_cast<const uint16_t*>(image->yuvPlanes[1]), image->yuvRowBytes[1],
                                                reinterpret_cast<const uint16_t*>(image->yuvPlanes[2]), image->yuvRowBytes[2],
                                                reinterpret_cast<const uint16_t*>(image->alphaPlane), image->alphaRowBytes,
                                                reinterpret_cast<uint16_t*>(data.data()), stride,
                                                image->width, image->height,
                                                pixartYuvRange, rType, yuvType);
                return AvifImageHandle {
                    .data = data,
                    .stride = stride,
                    .width = image->width,
                    .height = image->height,
                    .bitDepth = 8,
                    .components = 4
                };
            } else {
                RETURN_ERROR_HANDLE(result);
            }
        } else {
            RETURN_ERROR_HANDLE(result);
        }
    }
    
    if (highBitDepth) {
        if (components == 3) {
            AVIF_CHECK_RGB_PLANES_OR_RETURN(image, result);
            AVIF_CHECK_NOT_YUV400_OR_RETURN(image, result);
            uint32_t stride = image->width * 3 * sizeof(uint16_t);
            std::vector<uint8_t> data(stride * image->height);
            pixart_yuv16_to_rgb16(reinterpret_cast<const uint16_t*>(image->yuvPlanes[0]), image->yuvRowBytes[0],
                                  reinterpret_cast<const uint16_t*>(image->yuvPlanes[1]), image->yuvRowBytes[1],
                                  reinterpret_cast<const uint16_t*>(image->yuvPlanes[2]), image->yuvRowBytes[2],
                                  reinterpret_cast<uint16_t*>(data.data()), stride,
                                  bitDepth,
                                  image->width, image->height,
                                  pixartYuvRange, matrix, yuvType);
            return AvifImageHandle {
                .data = data,
                .stride = stride,
                .width = image->width,
                .height = image->height,
                .bitDepth = bitDepth,
                .components = 3
            };
        } else if (components == 4) {
            AVIF_CHECK_RGBA_PLANES_OR_RETURN(image, result);
            AVIF_CHECK_NOT_YUV400_OR_RETURN(image, result);
            uint32_t stride = image->width * 4 * sizeof(uint16_t);
            std::vector<uint8_t> data(stride * image->height);
            pixart_yuv16_with_alpha_to_rgba16(reinterpret_cast<const uint16_t*>(image->yuvPlanes[0]), image->yuvRowBytes[0],
                                              reinterpret_cast<const uint16_t*>(image->yuvPlanes[1]), image->yuvRowBytes[1],
                                              reinterpret_cast<const uint16_t*>(image->yuvPlanes[2]), image->yuvRowBytes[2],
                                              reinterpret_cast<const uint16_t*>(image->alphaPlane), image->alphaRowBytes,
                                              reinterpret_cast<uint16_t*>(data.data()), stride,
                                              bitDepth,
                                              image->width, image->height,
                                              pixartYuvRange, matrix, yuvType);
            return AvifImageHandle {
                .data = data,
                .stride = stride,
                .width = image->width,
                .height = image->height,
                .bitDepth = bitDepth,
                .components = 4
            };
        }
    } else {
        if (components == 3) {
            AVIF_CHECK_RGB_PLANES_OR_RETURN(image, result);
            AVIF_CHECK_NOT_YUV400_OR_RETURN(image, result);
            uint32_t stride = image->width * 3;
            std::vector<uint8_t> data(stride * image->height);
            pixart_yuv8_to_rgb8(image->yuvPlanes[0], image->yuvRowBytes[0],
                                image->yuvPlanes[1], image->yuvRowBytes[1],
                                image->yuvPlanes[2], image->yuvRowBytes[2],
                                data.data(), stride,
                                image->width, image->height,
                                pixartYuvRange, matrix, yuvType);
            return AvifImageHandle {
                .data = data,
                .stride = stride,
                .width = image->width,
                .height = image->height,
                .bitDepth = bitDepth,
                .components = 3
            };
        } else if (components == 4) {
            AVIF_CHECK_RGBA_PLANES_OR_RETURN(image, result);
            AVIF_CHECK_NOT_YUV400_OR_RETURN(image, result);
            uint32_t stride = image->width * 4;
            std::vector<uint8_t> data(stride * image->height);
            pixart_yuv8_with_alpha_to_rgba8(image->yuvPlanes[0], image->yuvRowBytes[0],
                                            image->yuvPlanes[1], image->yuvRowBytes[1],
                                            image->yuvPlanes[2], image->yuvRowBytes[2],
                                            image->alphaPlane, image->alphaRowBytes,
                                            data.data(), stride,
                                            image->width, image->height,
                                            pixartYuvRange, matrix, yuvType);
            return AvifImageHandle {
                .data = data,
                .stride = stride,
                .width = image->width,
                .height = image->height,
                .bitDepth = bitDepth,
                .components = 4
            };
        }
    }
    
    RETURN_ERROR_HANDLE(result);
}

- (_Nullable CGImageRef)formCGImage:(nonnull avifDecoder*)decoder scale:(CGFloat)scale {
    
    int avifHandleResult = AVIF_RESULT_UNKNOWN_ERROR;
    auto decodedImage = [AVIFImageXForm handleImage:decoder->image result:&avifHandleResult];
    if (avifHandleResult != AVIF_RESULT_OK) {
        return nullptr;
    }
    
    auto colorPrimaries = decoder->image->colorPrimaries;
    auto transferCharacteristics = decoder->image->transferCharacteristics;
    
    auto mColorSpaceDef = [ColorSpace queryColorSpace:colorPrimaries transferCharacteristics:transferCharacteristics];
    
    bool useHDR = mColorSpaceDef.wideGamut;
    
    CGColorSpaceRef colorSpace = nullptr;
    
    if(decoder->image->icc.data && decoder->image->icc.size) {
        CFDataRef iccData = CFDataCreate(kCFAllocatorDefault, decoder->image->icc.data, decoder->image->icc.size);
        colorSpace = CGColorSpaceCreateWithICCData(iccData);
        CFRelease(iccData);
    }
    
    if (!colorSpace) {
        colorSpace = mColorSpaceDef.mRef;
    }
    int flags;
    bool use10Bits = false;
    
    uint32_t depth = decodedImage.bitDepth;
    uint32_t newWidth = decodedImage.width;
    uint32_t newHeight = decodedImage.height;
    uint32_t stride = decodedImage.stride;
    auto components = decodedImage.components;
    auto imageUsesAlpha = decodedImage.components == 4;
    auto isImageRequires64Bit = decodedImage.bitDepth > 8;
    
    if ((depth == 10 || depth == 12 || depth == 16) && !useHDR && components == 3) {
        flags = (int)kCGImageByteOrderDefault | (int)kCGImagePixelFormatRGB101010 | (int)kCGImageAlphaLast;
        uint32_t lineWidth = newWidth * static_cast<uint32_t>(sizeof(uint32_t));
        uint32_t dstStride = lineWidth;
        vector<uint8_t> mVecRgb1010102(dstStride * newHeight);
        use10Bits = true;
        if (components == 3) {
            pixart_rgb_u16_to_ra30(reinterpret_cast<const uint16_t*>(decodedImage.data.data()), stride,
                                   mVecRgb1010102.data(), dstStride, depth, newWidth, newHeight);
        } else if (components == 4) {
            pixart_rgba_u16_to_ra30(reinterpret_cast<const uint16_t*>(decodedImage.data.data()), stride,
                                    mVecRgb1010102.data(), dstStride, depth, newWidth, newHeight);
        }
        components = 4;
        depth = 10;
        stride = dstStride;
        decodedImage.data = std::move(mVecRgb1010102);
    } else {
        if (isImageRequires64Bit) {
            if (components == 3) {
                pixart_rgb_u16_to_f16(reinterpret_cast<const uint16_t*>(decodedImage.data.data()), stride,
                                      reinterpret_cast<uint16_t*>(decodedImage.data.data()), stride,
                                      decodedImage.bitDepth,
                                      decodedImage.width, decodedImage.height);
            } else if (components == 4) {
                pixart_rgba_u16_to_f16(reinterpret_cast<const uint16_t*>(decodedImage.data.data()), stride,
                                       reinterpret_cast<uint16_t*>(decodedImage.data.data()), stride,
                                       decodedImage.bitDepth,
                                       decodedImage.width, decodedImage.height);
            }
            flags = (int)kCGImageByteOrder16Little | (int)kCGBitmapFloatComponents;
            if (imageUsesAlpha) {
                flags |= (int)kCGImageAlphaLast;
            } else {
                flags |= (int)kCGImageAlphaNone;
            }
            depth = 16;
        } else {
            flags = imageUsesAlpha ? (int)kCGBitmapByteOrder32Big : (int)kCGBitmapByteOrderDefault;
            if (imageUsesAlpha) {
                flags |= (int)kCGImageAlphaLast;
            } else {
                flags |= (int)kCGImageAlphaNone;
            }
        }
    }
    auto copiedData = std::move(decodedImage.data);
    XFormDataContainer* container = new XFormDataContainer(copiedData);
    CGDataProviderRef provider = CGDataProviderCreateWithData(container,
                                                              container->data(),
                                                              stride*newHeight,
                                                              XFormDataRelease);
    if (!provider) {
        return NULL;
    }
    
    int bitsPerPixel = (use10Bits || depth == 8) ? (8*components) : (16*components);
    
    CGImageRef imageRef = CGImageCreate(newWidth, newHeight, depth, bitsPerPixel,
                                        stride, colorSpace, flags, provider, NULL, false, kCGRenderingIntentDefault);
    return imageRef;
}

- (nullable Image*)form:(nonnull avifDecoder*)decoder scale:(CGFloat)scale {
    auto imageRef = [self formCGImage:decoder scale:scale];
    Image *image = nil;
#if TARGET_OS_OSX
    image = [[NSImage alloc] initWithCGImage:imageRef size:CGSizeZero];
#else
    image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
#endif
    CGImageRelease(imageRef);
    return image;
}

@end
