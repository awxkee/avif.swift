//
//  File.swift
//  
//
//  Created by Radzivon Bartoshyk on 01/05/2022.
//

import Foundation
import avifc
#if !os(macOS)
import UIKit
#else
import AppKit
#endif

public class AVIFEncoder {
    
    public static func encode(image: PlatformImage, quality: Double = 1.0, speed: Int = -1) throws -> Data {
        var newImage = image
        if newImage.size.width.truncatingRemainder(dividingBy: 2) != 0
            || newImage.size.height.truncatingRemainder(dividingBy: 2) != 0 {
            let newSize = CGSize(width: CGFloat((Int(newImage.size.width) / 2) * 2),
                                 height: CGFloat((Int(newImage.size.height) / 2) * 2))
            newImage = imageScaled(toScale: image, to: newSize)
        }
        return try AVIFEncoding().encode(newImage, speed: speed, quality: quality)
    }
    
    private static func imageScaled(toScale image: PlatformImage, to size: CGSize, scale: CGFloat? = nil) -> PlatformImage {
        assert(size.width > 0 && size.height > 0, "You cannot safely scale an image to a zero width or height")
        
        #if os(macOS)
        let destSize = NSMakeSize(CGFloat(size.width), CGFloat(size.height))
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        image.draw(in: NSMakeRect(0, 0, destSize.width, destSize.height), from: NSMakeRect(0, 0, image.size.width, image.size.height), operation: NSCompositingOperation.copy, fraction: CGFloat(1))
        newImage.unlockFocus()
        newImage.size = destSize
        return NSImage(data: newImage.tiffRepresentation!)!
        #else
        UIGraphicsBeginImageContextWithOptions(size, false, scale ?? image.scale)
        image.draw(in: CGRect(origin: .zero, size: size))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return scaledImage
        #endif
    }
    
}
