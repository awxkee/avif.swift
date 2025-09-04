//
//  AVIFEncoder.swift
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

import Foundation
import avifc
#if !os(macOS)
import UIKit
#else
import AppKit
#endif

public class AVIFEncoder {
    public static func encode(image: PlatformImage, quality: Double = 1.0, speed: Int = -1, preferredCodec: PreferredCodec = .AOM) throws -> Data {
        try AVIFEncoding().encode(image, speed: speed, quality: quality, yuv: .yuv420, avifRangeFill: false, preferredCodec: preferredCodec)
    }
    
    public static func encode(image: PlatformImage, with param: EncodeParameter) throws -> Data {
        try AVIFEncoding().encode(image, speed: param.speed, quality: param.quality, yuv: param.yuv, avifRangeFill: param.avifRangeFill, preferredCodec: param.preferredCodec)
    }
}

public struct EncodeParameter {
    var quality: Double = 1.0
    var yuv: Yuv = .yuv420
    var avifRangeFill: Bool
    var speed: Int = -1
    var preferredCodec: PreferredCodec = .AOM
}
