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

    private static let queue = OperationQueue()

    @Published private(set) var url: URL?
    private var handle: FileHandle?

    private var bytesWritten: Int = 0
    private var expectedSize: Int64?

    init(url: URL, expectedSize: Int64?) {
        let fm = FileManager()
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil, attributes: nil)
        }
        self.url = url
        handle = FileHandle(forWritingAtPath: url.path)
        self.expectedSize = expectedSize
        super.init()
        
        NSFileCoordinator.addFilePresenter(self)
    }

    func close() {
        handle?.closeFile()
        handle = nil
    }

    func move(to newURL: URL, incrementingIndexIfExists: Bool) throws -> URL {
        guard let currentURL = self.url,
              currentURL != newURL
        else { return newURL }

        let resultURL = try FileManager().moveItem(at: currentURL, to: newURL, incrementingIndexIfExists: incrementingIndexIfExists)
        #warning("recreate FileHandle if moving to different volumt")
        self.url = resultURL

        return resultURL
    }

    func write(_ data: Data) {
        self.handle?.write(data)
        bytesWritten += data.count

        if let expectedSize = expectedSize,
           let url = self.url {
            let fractionCompleted = Double(bytesWritten) / Double(expectedSize)
            try? FileManager.default.setFractionCompleted(fractionCompleted, at: url)
        }
    }

    func delete() throws {
        guard let url = url else { return }
        close()
        try FileManager().removeItem(at: url)

        self.url = nil
    }

    deinit {
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

}
