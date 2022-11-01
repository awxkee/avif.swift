//
//  File.swift
//  
//
//  Created by Radzivon Bartoshyk on 22/06/2022.
//

import Foundation
import avifc

public class AnimatedDecoder {
    
    private let _decoder: AVIFAnimatedDecoder
    
    public init(data: Data) throws {
        guard let decoder = AVIFAnimatedDecoder(data: data) else {
            throw AVIFReadError()
        }
        _decoder = decoder
    }
    
    public var numberOfFrames: Int {
        return Int(_decoder.framesCount())
    }
    
    public var duration: Int {
        return Int(_decoder.duration())
    }
    
    public func duration(of frame: Int) -> Int {
        return Int(_decoder.frameDuration(Int32(frame)))
    }
    
    public func getImage(frame: Int) throws -> PlatformImage {
        guard let image = _decoder.getImage(Int32(frame)) else {
            throw AVIFDecodingError()
        }
        return image
    }
    
    public func get(frame: Int) throws -> CGImage {
        guard let image = _decoder.get(Int32(frame)) else {
            throw AVIFDecodingError()
        }
        return image.takeRetainedValue()
    }
    
}
