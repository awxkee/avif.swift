//
//  Data+AVIFFormat.swift
//  Nuke-AVIF-Plugin iOS
//
//  Created by delneg on 2021/12/05.
//  Copyright © 2021 delneg. All rights reserved.
//

//https://www.garykessler.net/library/file_sigs.html
import Foundation

public extension Data {

    var isAVIFFormat: Bool {
        do {
            let ss = try AVIFDecoder().readSize(self)
            return ss.width > 0 && ss.height > 0
        } catch {
            return false
        }
    }

}
