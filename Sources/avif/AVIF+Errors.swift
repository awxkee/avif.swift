//
//  AVIF+Errors.swift
//  
//
//  Created by Radzivon Bartoshyk on 27/05/2022.
//

import Foundation

public struct AVIFReadError: Error, Equatable { }
public struct OpenStreamError: Error, Equatable { }
public struct AVIFDecodingError: Error, Equatable { }

public struct AVIFUnderlyingError: LocalizedError {
    let underlyingError: String
    
    public var errorDescription: String? {
        underlyingError
    }
}
