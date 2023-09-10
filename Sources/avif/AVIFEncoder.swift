//
//  AVIFEncoder.swift
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 01/05/2022.
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
        image.draw(in: NSMakeRect(0, 0, destSize.width, destSize.height),
                   from: NSMakeRect(0, 0, image.size.width, image.size.height),
                   operation: NSCompositingOperation.copy,
                   fraction: CGFloat(1))
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
