//
//  AVIF+Errors.swift
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 27/05/2022.
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

public struct AVIFReadError: LocalizedError, CustomNSError { 
    public var errorDescription: String {
        "Can't read AVIF data"
    }

    public var errorUserInfo: [String : Any] {
        [NSLocalizedDescriptionKey: errorDescription]
    }
}

public struct OpenStreamError: LocalizedError, CustomNSError {
    public var errorDescription: String {
        "Can't open AVIF Stream"
    }

    public var errorUserInfo: [String : Any] {
        [NSLocalizedDescriptionKey: errorDescription]
    }
}

public struct AVIFDecodingError: LocalizedError, CustomNSError {
    public var errorDescription: String {
        "Can't decode AVIF"
    }

    public var errorUserInfo: [String : Any] {
        [NSLocalizedDescriptionKey: errorDescription]
    }
}

public struct AVIFFrameDecodingError: LocalizedError, CustomNSError {
    public var frame: Int
    public var errorDescription: String {
        "Can't decode frame at index: \(frame) in AVIF"
    }

    public var errorUserInfo: [String : Any] {
        [NSLocalizedDescriptionKey: errorDescription]
    }
}

public struct AVIFUnderlyingError: LocalizedError, CustomNSError {
    let underlyingError: String
    
    public var errorDescription: String {
        underlyingError
    }

    public var errorUserInfo: [String : Any] {
        [NSLocalizedDescriptionKey: errorDescription]
    }
}
