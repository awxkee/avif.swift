//
//  Data+AVIFFormat.swift
//  Nuke-AVIF-Plugin iOS
//
//  Created by delneg on 2021/12/05.
//  Copyright © 2021 delneg. All rights reserved.
//

//https://www.garykessler.net/library/file_sigs.html
import Foundation

private let fileHeaderIndex: Int = 4

private let avifBytes: [UInt8] = [
    0x66, 0x74, 0x79, 0x70, // ftyp
    0x61, 0x76, 0x69, 0x66  // avif
]
private let avifMif: [UInt8] = [UInt8]("ftypmif1".data(using: .utf8)!)
private let avifMsf: [UInt8] = [UInt8]("ftypmsf1".data(using: .utf8)!)
private let avifAvis: [UInt8] = [UInt8]("ftypavis".data(using: .utf8)!)
private let magicBytesEndIndex: Int = fileHeaderIndex+avifBytes.count
// MARK: - AVIF Format Testing
public extension Data {

    var isAVIFFormat: Bool {
        guard magicBytesEndIndex < count else { return false }
        let bytesStart = index(startIndex, offsetBy: fileHeaderIndex)
        let data = subdata(in: bytesStart..<magicBytesEndIndex)
        return data.elementsEqual(avifBytes)
            || data.elementsEqual(avifMif)
            || data.elementsEqual(avifMsf)
            || data.elementsEqual(avifAvis)
    }

}
