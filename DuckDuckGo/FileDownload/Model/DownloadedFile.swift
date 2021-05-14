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

final class DownloadedFile {

    private static let queue = DispatchQueue(label: "DownloadedFile.queue", qos: .background)

    private var bookmark: Data?

    // CurrentValueSubject used under the hood has locked value access so it's thread safe
    @PublishedAfter private(set) var url: URL?
    @PublishedAfter private(set) var bytesWritten: UInt64 = 0

    private var handle: FileHandle? {
        didSet {
            guard let handle = handle else {
                self.fsSource = nil
                return
            }
            self.fsSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: handle.fileDescriptor,
                                                                      eventMask: [.rename, .delete],
                                                                      queue: Self.queue)
        }
    }
    private var fsSource: DispatchSourceFileSystemObject? {
        didSet {
            oldValue?.cancel()
            fsSource?.setEventHandler { [weak self] in
                self?.fileSystemSourceCallback()
            }
            fsSource?.resume()
        }
    }

    init(url: URL, offset: UInt64 = 0) throws {
        self.url = url

        try self.open(url: url, offset: offset)
    }

    private func open(url: URL, offset: UInt64) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil, attributes: nil)
        }
        self.url = url
        self.bookmark = try? url.bookmarkData()
        let handle = try FileHandle(forWritingTo: url)

        do {
            try handle.seek(toOffset: offset)
            try handle.truncate(atOffset: offset)
            self.bytesWritten = offset
        } catch {
            try handle.seek(toOffset: 0)
            try handle.truncate(atOffset: 0)
            self.bytesWritten = 0
        }
        self.handle = handle
    }

    private func fileSystemSourceCallback() {
        if let currentURL = locateFile() {
            if currentURL != self.url {
                self.url = currentURL
            }
        } else { // file has been removed
            self._close()
            self.url = nil
        }
    }

    private func locateFile() -> URL? {
        if let url = self.url,
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        var isStale = false
        if let bookmark = self.bookmark,
           let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale) {
            if isStale, let newData = try? url.bookmarkData() {
                self.bookmark = newData
            }
            return url
        }
        return nil
    }

    private func _close() {
        handle?.closeFile()
        handle = nil
    }

    func close() {
        Self.queue.async {
            self._close()
        }
    }

    private func _move(to newURL: URL, incrementingIndexIfExists: Bool, pathExtension: String?) throws -> URL {
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
            handle = try FileHandle(forWritingTo: resultURL)
            handle!.seekToEndOfFile()
        }
        self.url = resultURL

        return resultURL
    }

    func move(to newURL: URL, incrementingIndexIfExists: Bool, pathExtension: String? = nil) throws -> URL {
        return try Self.queue.sync {
            return try self._move(to: newURL, incrementingIndexIfExists: incrementingIndexIfExists, pathExtension: pathExtension)
        }
    }

    func write(_ data: Data) {
        Self.queue.async { [weak self] in
            guard let self = self,
                  let handle = self.handle
            else { return }
            handle.write(data)
            self.bytesWritten += UInt64(data.count)
        }
    }

    func delete() {
        Self.queue.async { [self] in
            self._close()

            guard let url = url else { return }
            try? FileManager().removeItem(at: url)

            self.url = nil
        }
    }

    deinit {
        fsSource?.cancel()
        handle?.closeFile()
    }

}
