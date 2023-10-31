//
//  SDWebImageAVIFCoder.swift
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 30/08/2023.
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
import SDWebImage
#if canImport(avif)
import avif
#endif
#if !os(macOS)
import UIKit.UIImage
import UIKit.UIColor
/// Alias for `UIImage`.
public typealias AVIFSDImage = UIImage
#else
import AppKit.NSImage
/// Alias for `NSImage`.
public typealias AVIFSDImage = NSImage
#endif

public class SDWebImageAVIFCoder: NSObject, SDAnimatedImageCoder {
    private let decoder: AnimatedDecoder?
    private let mAnimatedData: Data?

    public required init?(animatedImageData data: Data?, options: [SDImageCoderOption : Any]? = nil) {
        guard let data, let mDecoder = try? AnimatedDecoder(data: data) else {
            return nil
        }
        decoder = mDecoder
        self.mAnimatedData = data
        super.init()
    }

    public override init() {
        self.decoder = nil
        self.mAnimatedData = nil
    }

    public func canDecode(from data: Data?) -> Bool {
        guard let data else {
            return false
        }
        return AVIFDecoder().isAVIF(data: data)
    }

    public func decodedImage(with data: Data?, options: [SDImageCoderOption : Any]? = nil) -> AVIFSDImage? {
        guard let data else {
            return nil
        }
        return AVIFDecoder.decode(data)
    }

    public func canEncode(to format: SDImageFormat) -> Bool {
        return true
    }

    public func encodedData(with image: AVIFSDImage?, format: SDImageFormat, options: [SDImageCoderOption : Any]? = nil) -> Data? {
        guard let image else {
            return nil
        }
        return try? AVIFEncoder.encode(image: image, quality: 50)
    }

    public var animatedImageData: Data? {
        nil
    }

    public var animatedImageFrameCount: UInt {
        guard let decoder else { return 0 }
        return UInt(decoder.numberOfFrames)
    }

    public var animatedImageLoopCount: UInt {
        guard let decoder else { return 0 }
        return UInt(decoder.loopsCount)
    }

    public func animatedImageFrame(at index: UInt) -> AVIFSDImage? {
        guard let decoder else { return nil }
        return try? decoder.getImage(frame: Int(index))
    }

    public func animatedImageDuration(at index: UInt) -> TimeInterval {
        guard let decoder else { return 0 }
        return TimeInterval(decoder.duration(of: Int(index))) / 1000
    }

}
