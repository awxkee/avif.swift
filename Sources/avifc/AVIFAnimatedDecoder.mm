//
//  AVIFAnimatedDecoder.mm
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 22/06/2022.
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

#import "AVIFAnimatedDecoder.h"
#import "avif/avif.h"
#import <Accelerate/Accelerate.h>
#import "AVIFRGBAMultiplier.h"
#import "PlatformImage.h"
#import "AVIFImageXForm.h"
#import <thread>

@implementation AVIFAnimatedDecoder {
    avifDecoder *_idec;
}

-(nullable id)initWithData:(nonnull NSData*)data {
    _idec = avifDecoderCreate();

    avifDecoderSetIOMemory(_idec, reinterpret_cast<const uint8_t*>(data.bytes), data.length);
    CGFloat scale = 1;
    
    _idec->strictFlags = AVIF_STRICT_DISABLED;
    _idec->ignoreXMP = true;
    _idec->ignoreExif = true;
    _idec->maxThreads = std::thread::hardware_concurrency();
    avifResult decodeResult = avifDecoderParse(_idec);
    if (decodeResult != AVIF_RESULT_OK) {
        avifDecoderDestroy(_idec);
        _idec = nullptr;
        return nil;
    }
    return self;
}

-(nullable Image*)getImage:(int)frame {
    CGImageRef ref = [self get:frame];
    if (!ref) return NULL;
    Image *image = nil;
#if TARGET_OS_OSX
    image = [[NSImage alloc] initWithCGImage:ref size:CGSizeZero];
#else
    image = [UIImage imageWithCGImage:ref scale:1 orientation:UIImageOrientationUp];
#endif
    return image;
}

-(nullable CGImageRef)get:(int)frame {
    avifResult nextImageResult = avifDecoderNthImage(_idec, frame);
    if (nextImageResult != AVIF_RESULT_OK) {
        return nil;
    }
    auto xForm = [[AVIFImageXForm alloc] init];
    return [xForm formCGImage:_idec scale:1];
}

-(int)frameDuration:(int)frame {
    avifImageTiming timing;
    avifDecoderNthImageTiming(_idec, frame, &timing);
    return (int)(1000.0f / ((float)timing.timescale) * (float)timing.durationInTimescales);
}

-(int)framesCount {
    return _idec->imageCount;
}

-(int)loopsCount {
    return _idec->repetitionCount;
}

-(int)duration {
    return (int)(1000.0f / ((float)_idec->timescale) * (float)_idec->durationInTimescales);
}

-(CGSize)imageSize {
    return CGSizeMake(_idec->image->width, _idec->image->height);
}

- (void)dealloc {
    if (_idec) {
        avifDecoderDestroy(_idec);
        _idec = NULL;
    }
}

@end
