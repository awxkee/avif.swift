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

public class AVIFImageDecoder {

    private lazy var decoder: AVIFDataDecoder = AVIFDataDecoder()
    
    public static let AVIF_DEFAULT_IMAGE_SIZE_LIMIT = 16384

    public init() {
    }
    
    public func decode(_ data: Data, sampleSize: CGSize = .zero) -> PlatformImage? {
        guard data.isAVIFFormat else { return nil }
        let iStream = InputStream(data: data)
        guard let image = try? decoder.decode(iStream, sampleSize: sampleSize, maxContentSize: 0) else { return nil }
        return image
    }

    public func decodePartiallyDownloadedData(_ data: Data) -> PlatformImage? {
        guard data.isAVIFFormat else { return nil }
        guard let image = decoder.incrementallyDecode(data) else { return nil }
        return image
    }
    
    public func readSize(_ data: Data) throws -> CGSize {
        guard data.isAVIFFormat else { throw AVIFReadError() }
        let value = try decoder.readSize(data)
        return value.cgSizeValue
    }
    
    public func readSize(path: String) throws -> CGSize {
        let value = try decoder.readSize(fromPath: path)
        return value.cgSizeValue
    }
    
    public func readSize(at: URL) throws -> CGSize {
        return try readSize(path: at.path)
    }
    
    public func decode(at: URL, sampleSize: CGSize) throws -> PlatformImage {
        guard let iStream = InputStream(url: at) else {
            throw OpenStreamError()
        }
        let image = try decoder.decode(iStream, sampleSize: sampleSize, maxContentSize: UInt(1024*1024*10))
        return image
    }

}
