//
//  AnimatedEncoder.swift
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 22/06/2022.
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

public class AnimatedDecoder {
    
    private let mAVIFAnimatedDecoder: AVIFAnimatedDecoder
    
    public init(data: Data) throws {
        guard let decoder = AVIFAnimatedDecoder(data: data) else {
            throw AVIFReadError()
        }
        mAVIFAnimatedDecoder = decoder
    }
    
    public var numberOfFrames: Int {
        return Int(mAVIFAnimatedDecoder.framesCount())
    }

    public var loopsCount: Int {
        Int(mAVIFAnimatedDecoder.loopsCount())
    }

    public var duration: Int {
        return Int(mAVIFAnimatedDecoder.duration())
    }
    
    public func duration(of frame: Int) -> Int {
        return Int(mAVIFAnimatedDecoder.frameDuration(Int32(frame)))
    }

    public func getImage(frame: Int) throws -> PlatformImage {
        guard let image = mAVIFAnimatedDecoder.getImage(Int32(frame)) else {
            throw AVIFFrameDecodingError(frame: frame)
        }
        return image
    }
    
    public func get(frame: Int) throws -> CGImage {
        guard let image = mAVIFAnimatedDecoder.get(Int32(frame)) else {
            throw AVIFFrameDecodingError(frame: frame)
        }
        return image.takeRetainedValue()
    }
    
}
