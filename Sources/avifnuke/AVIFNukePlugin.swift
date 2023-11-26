//
//  AVIFNukePlugin.swift
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 26/06/2022.
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
import Nuke
#if canImport(avif)
import avif
#endif

public final class AVIFNukePlugin: Nuke.ImageDecoding {

    public init() {
    }
    
    public func decode(_ data: Data) throws -> ImageContainer {
        guard data.isAVIFFormat else { throw AVIFNukePluginDecodeError() }
        guard let image = AVIFDecoder.decode(data) else { throw AVIFNukePluginDecodeError() }
        return ImageContainer(image: image)
    }

    public func decodePartiallyDownloadedData(_ data: Data) -> ImageContainer? {
        return nil
    }

    public struct AVIFNukePluginDecodeError: LocalizedError, CustomNSError {
        public var errorDescription: String {
            "AVIF doesn't seems to be valid"
        }

        public var errorUserInfo: [String : Any] {
            [NSLocalizedDescriptionKey: errorDescription]
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
