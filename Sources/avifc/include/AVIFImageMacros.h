//
//  AVIFImageMacros.h
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

#import <TargetConditionals.h>

#ifndef AVIFImageMacros_h
#define AVIFImageMacros_h

#if !TARGET_OS_IPHONE && !TARGET_OS_IOS && !TARGET_OS_TV && !TARGET_OS_WATCH
    #define AVIF_PLUGIN_MAC 1
#else
    #define AVIF_PLUGIN_MAC 0
#endif

#if TARGET_OS_IOS || TARGET_OS_TV
    #define AVIF_PLUGIN_UIKIT 1
#else
    #define AVIF_PLUGIN_UIKIT 0
#endif

#if TARGET_OS_IOS
    #define AVIF_PLUGIN_IOS 1
#else
    #define AVIF_PLUGIN_IOS 0
#endif

#if TARGET_OS_TV
    #define AVIF_PLUGIN_TV 1
#else
    #define AVIF_PLUGIN_TV 0
#endif

#endif /* AVIFImageMacros_h */
