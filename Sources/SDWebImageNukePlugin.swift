//
//  File.swift
//  
//
//  Created by Radzivon Bartoshyk on 30/08/2023.
//

import Foundation
import SDWebImage
#if canImport(avif)
import avif
#endif

public class SDWebImageAVIFCoder: NSObject, SDImageCoder {
    public func canDecode(from data: Data?) -> Bool {
        guard let data else { return false }
        return data.isAVIFFormat
    }

    public func decodedImage(with data: Data?, options: [SDImageCoderOption : Any]? = nil) -> UIImage? {
        guard let data else {
            return nil
        }
        return AVIFDecoder.decode(data)
    }

    public func canEncode(to format: SDImageFormat) -> Bool {
        return true
    }

    public func encodedData(with image: UIImage?, format: SDImageFormat, options: [SDImageCoderOption : Any]? = nil) -> Data? {
        guard let image else {
            return nil
        }
        return try? AVIFEncoder.encode(image: image, quality: 50)
    }

    public override init() {
    }
}
