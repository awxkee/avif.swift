//
//  AVIFNukePlugin.swift
//  
//
//  Created by Radzivon Bartoshyk on 26/06/2022.
//

import Foundation
import Nuke
@preconcurrency import avif

public final class AVIFNukePlugin: Nuke.ImageDecoding {

    private let decoder = AVIFDecoder()

    public init() {
    }
    
    public func decode(_ data: Data) throws -> ImageContainer {
        guard data.isAVIFFormat else { throw AVIFNukePluginDecodeError() }
        guard let image = decoder.decode(data) else { throw AVIFNukePluginDecodeError() }
        return ImageContainer(image: image)
    }

    public func decodePartiallyDownloadedData(_ data: Data) -> ImageContainer? {
        return nil
    }

    public struct AVIFNukePluginDecodeError: LocalizedError {
        public var errorDescription: String? {
            "AVIF doesn't seems to be valid"
        }
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