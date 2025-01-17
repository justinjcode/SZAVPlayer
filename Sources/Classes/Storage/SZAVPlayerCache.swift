//
//  SZAVPlayerCache.swift
//
//  Created by CaiSanze on 2019/11/27.
//

import UIKit

public class SZAVPlayerCache: NSObject {

    private let videoCacheQueue: DispatchQueue = DispatchQueue(label: "com.SZAVPlayer.videoCacheQueue", qos: .userInitiated)
    
    public static let shared: SZAVPlayerCache = SZAVPlayerCache()

    private var maxCacheSize: Int64 = 0

    override init() {
        super.init()

        setup(maxCacheSize: 100)
        trimCache()
    }

    /// Setup
    /// - Parameter maxCacheSize: Unit: MB
    public func setup(maxCacheSize: Int64) {
        self.maxCacheSize = maxCacheSize
        SZAVPlayerFileSystem.createCacheDirectory()
    }

    public func save(uniqueID: String, mediaData: Data, startOffset: Int64) {
        let newFileName = SZAVPlayerLocalFileInfo.newFileName(uniqueID: uniqueID, startOffset: startOffset)
        let localFilePath = SZAVPlayerFileSystem.localFilePath(fileName: newFileName)
        if SZAVPlayerFileSystem.write(data: mediaData, url: localFilePath) {
            let fileInfo = SZAVPlayerLocalFileInfo(uniqueID: uniqueID,
                                                   startOffset: startOffset,
                                                   loadedByteLength: Int64(mediaData.count),
                                                   localFileName: newFileName)
            SZAVPlayerDatabase.shared.update(fileInfo: fileInfo)
        }

        trimCache()
    }

    public func delete(uniqueID: String) {
        SZAVPlayerDatabase.shared.trimData(uniqueID: uniqueID)
    }

    public func cleanCache() {
        SZAVPlayerDatabase.shared.cleanData()
        SZAVPlayerFileSystem.cleanCachedFiles()
    }

    public func isFullyCached(uniqueID: String) -> Bool {
        let info = SZAVPlayerDatabase.shared.contentInfo(uniqueID: uniqueID)
        let localFileInfos = SZAVPlayerDatabase.shared.localFileInfos(uniqueID: uniqueID)
        guard let contentInfo = info, contentInfo.contentLength > 0,
            localFileInfos.count > 0 else
        {
            SZLogDebug("isFullyCached uniqueId:\(uniqueID) false")
            return false
        }

        var startOffset = Int64(0)
        let endOffset = contentInfo.contentLength
        for fileInfo in localFileInfos {
            if SZAVPlayerDataLoader.isOutOfRange(startOffset: startOffset, endOffset: endOffset, fileInfo: fileInfo) {
                break
            }

            let localFileStartOffset = fileInfo.startOffset
            if startOffset >= localFileStartOffset {
                let localFileStartOffset = max(0, startOffset - fileInfo.startOffset)
                let localFileUsefulLength = min(fileInfo.loadedByteLength - localFileStartOffset, endOffset)
                startOffset = startOffset + localFileUsefulLength
            } else {
                break
            }
        }

        let isFullyCached = startOffset >= endOffset
        SZLogDebug("isFullyCached uniqueId:\(uniqueID) \(isFullyCached)")
        return isFullyCached
    }

    public func trimCache() {
        videoCacheQueue.async {
            
            var totalFileSize = self.getTotalCacheSize()

            totalFileSize /= 1024 * 1024
            if totalFileSize >= self.maxCacheSize {
                SZAVPlayerDatabase.shared.trimData()
            }
        }
    }
    
    public func getTotalCacheSize() -> Int64 {
        let directory = SZAVPlayerFileSystem.cacheDirectory
        let allFiles: [URL] = SZAVPlayerFileSystem.allFiles(path: directory)
        var totalFileSize: Int64 = 0
        for file in allFiles {
            if let attributes = SZAVPlayerFileSystem.attributes(url: file.path),
                let fileSize = attributes[FileAttributeKey.size] as? Int64
            {
                totalFileSize += fileSize
            }
        }
        return totalFileSize
    }

}

// MARK: - Getter

extension SZAVPlayerCache {

    public static func dataExist(uniqueID: String) -> Bool {
        return SZAVPlayerFileSystem.isExist(url: fileURL(uniqueID: uniqueID))
    }

    private static func fileURL(uniqueID: String) -> URL {
        return SZAVPlayerFileSystem.cacheDirectory.appendingPathComponent(uniqueID)
    }

}
