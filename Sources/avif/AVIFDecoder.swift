//
//  AVIFImage.swift
//  Nuke-AVIF-Plugin
//
//  Created by delneg on 2021/12/05.
//  Copyright © 2021 delneg. All rights reserved.
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

    public static func decode(_ data: Data, sampleSize: CGSize = .zero) -> PlatformImage? {
        let iStream = InputStream(data: data)
        guard let image = try? AVIFDataDecoder().decode(iStream, sampleSize: sampleSize, maxContentSize: 0) else { return nil }
        return image
    }

    public static func decode(from data: Data, sampleSize: CGSize = .zero) throws -> PlatformImage {
        let iStream = InputStream(data: data)
        let image = try AVIFDataDecoder().decode(iStream, sampleSize: sampleSize, maxContentSize: 0)
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
    
    public static func decode(at: URL, sampleSize: CGSize = .zero) throws -> PlatformImage {
        guard let iStream = InputStream(url: at) else {
            throw OpenStreamError()
        }
        let image = try AVIFDataDecoder().decode(iStream, sampleSize: sampleSize, maxContentSize: UInt(1024*1024*10))
        return image
    }

}
