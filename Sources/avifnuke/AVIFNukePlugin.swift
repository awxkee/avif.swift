//
//  AVIFNukePlugin.swift
//  
//
//  Created by Radzivon Bartoshyk on 26/06/2022.
//

import Foundation
import Nuke
import avif

public class AVIFNukePlugin: Nuke.ImageDecoding {

    private let decoder = AVIFDecoder()

    public init() {
    }
    
    public func decode(_ data: Data) -> ImageContainer? {
        guard data.isAVIFFormat else { return nil }
        guard let image = decoder.decode(data) else { return nil }
        return ImageContainer(image: image)
    }

    public func decodePartiallyDownloadedData(_ data: Data) -> ImageContainer? {
        return nil
    }

}

// MARK: - check avif format data.
extension AVIFNukePlugin {

    public static func enable() {
        Nuke.ImageDecoderRegistry.shared.register { (context) -> ImageDecoding? in
            AVIFNukePlugin.enable(context: context)
        }
    }

    public static func enable(context: Nuke.ImageDecodingContext) -> Nuke.ImageDecoding? {
        return context.data.isAVIFFormat ? AVIFNukePlugin() : nil
    }

}
