//
//  SZAVPlayerLocalFileInfo.swift
//  SZAVPlayer
//
//  Created by CaiSanze on 2019/12/6.
//

import UIKit

public struct SZAVPlayerLocalFileInfo: SZBaseModel {

    static var tableName: String = "SZAVPlayerLocalFileInfo"

    var uniqueID: String
    var startOffset: Int64
    var loadedByteLength: Int64
    var localFileName: String
    var updated: Int64 = 0

    static func newFileName(uniqueID: String, startOffset: Int64) -> String {
        return "\(uniqueID)_\(startOffset)"
    }

}
