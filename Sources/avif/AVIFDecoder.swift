//
//  AVIFDecoder.swift
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 12/12/2021.
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
import UIKit.UIImage
import UIKit.UIColor
/// Alias for `UIImage`.
public typealias PlatformImage = UIImage
#else
import AppKit.NSImage
/// Alias for `NSImage`.
public typealias PlatformImage = NSImage
#endif

public final class AVIFDecoder {

    private lazy var decoder: AVIFDataDecoder = AVIFDataDecoder()
    
    public static let AVIF_DEFAULT_IMAGE_SIZE_LIMIT = 16384

    public init() {
    }

    public func isAVIF(data: Data) -> Bool {
        do {
            let ss = try AVIFDecoder.readSize(data: data)
            return ss.width > 0 && ss.height > 0
        } catch {
            return false
        }
    }

    public func decodePartiallyDownloadedData(_ data: Data) -> PlatformImage? {
        guard let image = decoder.incrementallyDecode(data) else { return nil }
        return image
    }

    public static func decode(_ data: Data, scale: CGFloat = 1, sampleSize: CGSize = .zero) -> PlatformImage? {
        let iStream = InputStream(data: data)
        guard let image = try? AVIFDataDecoder().decode(iStream, sampleSize: sampleSize, maxContentSize: 0, scale: scale) else { return nil }
        return image
    }

    public static func decode(from data: Data, scale: CGFloat = 1, sampleSize: CGSize = .zero) throws -> PlatformImage {
        let iStream = InputStream(data: data)
        let image = try AVIFDataDecoder().decode(iStream, sampleSize: sampleSize, maxContentSize: 0, scale: scale)
        return image
    }

    public static func readSize(data: Data) throws -> CGSize {
        guard let decoder = avifDecoderCreate() else {
            throw AVIFUnderlyingError(underlyingError: "Can't initialize decoder")
        }
        defer { avifDecoderDestroy(decoder) }
        let result = try data.withUnsafeBytes { pointer in
            var result = avifDecoderSetIOMemory(decoder, pointer.baseAddress!.assumingMemoryBound(to: UInt8.self), data.count)
            if result != AVIF_RESULT_OK {
                throw AVIFUnderlyingError(underlyingError: String(utf8String: avifResultToString(result)) ?? "Unknown error")
            }
            decoder.pointee.strictFlags = AVIF_STRICT_DISABLED.rawValue
            result = avifDecoderParse(decoder)
            if result != AVIF_RESULT_OK {
                throw AVIFUnderlyingError(underlyingError: String(utf8String: avifResultToString(result)) ?? "Unknown error")
            }
            let size = CGSize(width: CGFloat(decoder.pointee.image.pointee.width), height: CGFloat(decoder.pointee.image.pointee.height))
            return size
        }
        return result
    }

    public static func readSize(path: String) throws -> CGSize {
        guard let decoder = avifDecoderCreate() else {
            throw AVIFUnderlyingError(underlyingError: "Can't initialize decoder")
        }
        defer { avifDecoderDestroy(decoder) }
        var result = avifDecoderSetIOFile(decoder, (path as NSString).fileSystemRepresentation)
        if result != AVIF_RESULT_OK {
            throw AVIFUnderlyingError(underlyingError: String(utf8String: avifResultToString(result)) ?? "Unknown error")
        }
        decoder.pointee.strictFlags = AVIF_STRICT_DISABLED.rawValue
        result = avifDecoderParse(decoder)
        if result != AVIF_RESULT_OK {
            throw AVIFUnderlyingError(underlyingError: String(utf8String: avifResultToString(result)) ?? "Unknown error")
        }
        let size = CGSize(width: CGFloat(decoder.pointee.image.pointee.width), height: CGFloat(decoder.pointee.image.pointee.height))
        return size
    }

    public static func readSize(at: URL) throws -> CGSize {
        return try readSize(path: at.path)
    }
    
    public static func decode(at: URL, scale: CGFloat = 1, sampleSize: CGSize = .zero) throws -> PlatformImage {
        guard let iStream = InputStream(url: at) else {
            throw OpenStreamError()
        }
        let image = try AVIFDataDecoder().decode(iStream, sampleSize: sampleSize, maxContentSize: UInt(1024*1024*10), scale: scale)
        return image
    }

}
