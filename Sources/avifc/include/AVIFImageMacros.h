//
//  AVIFImageMacros.h
//
//  Created by Radzivon Bartoshyk on 01/05/2022.
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
