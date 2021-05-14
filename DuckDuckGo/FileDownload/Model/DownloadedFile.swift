//
//  DownloadedFile.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import Combine

final class DownloadedFile: NSObject {

    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "DownloadedFile.queue"
        queue.isSuspended = false
        return queue
    }()

    @Published private(set) var url: URL?
    @Published private(set) var bytesWritten: UInt64 = 0

    private var handle: FileHandle?

    init(url: URL, offset: UInt64 = 0) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil, attributes: nil)
        }
        self.url = url
        handle = FileHandle(forWritingAtPath: url.path)

        do {
            try handle!.seek(toOffset: offset)
            try handle!.truncate(atOffset: offset)
            self.bytesWritten = offset
        } catch {
            handle!.seek(toFileOffset: 0)
            handle!.truncateFile(atOffset: 0)
            self.bytesWritten = 0
        }

        super.init()
        
        NSFileCoordinator.addFilePresenter(self)
    }

    func close() {
        handle?.closeFile()
        handle = nil
    }

    func move(to newURL: URL, incrementingIndexIfExists: Bool, pathExtension: String? = nil) throws -> URL {
        guard let currentURL = self.url,
              currentURL != newURL
        else { return newURL }

        let oldURLVolume = try? currentURL.resourceValues(forKeys: [.volumeURLKey]).volume
        let newURLVolume = try? newURL.resourceValues(forKeys: [.volumeURLKey]).volume
        if let handle = handle,
           oldURLVolume == nil || oldURLVolume != newURLVolume {
            // reopen FileHandle when moving file between different volumes
            handle.synchronizeFile()
            handle.closeFile()
        }

        let resultURL = try FileManager.default.moveItem(at: currentURL,
                                                         to: newURL,
                                                         incrementingIndexIfExists: incrementingIndexIfExists,
                                                         pathExtension: pathExtension)

        if handle != nil,
           oldURLVolume == nil || oldURLVolume != newURLVolume {
            handle = FileHandle(forWritingAtPath: resultURL.path)
            handle!.seekToEndOfFile()
        }
        self.url = resultURL

        return resultURL
    }

    func write(_ data: Data) {
        #warning("written in urlrequest callback, moved to in main thread")
        self.handle?.write(data)
        bytesWritten += UInt64(data.count)
    }

    func delete() {
        guard let url = url else { return }
        close()
        try? FileManager().removeItem(at: url)

        self.url = nil
    }

    deinit {
        #warning("not deinited as it's added")
        NSFileCoordinator.removeFilePresenter(self)
    }

}

extension DownloadedFile: NSFilePresenter {

    var presentedItemURL: URL? {
        self.url
    }

    var presentedItemOperationQueue: OperationQueue {
        Self.queue
    }

    func presentedItemDidMove(to newURL: URL) {
        self.url = newURL
    }

    func presentedItemDidChange() {
        // TODO: use GCD file mon?
        if let url = self.url,
           !FileManager.default.fileExists(atPath: url.path) {
            close()
            self.url = nil
        }
    }

}
