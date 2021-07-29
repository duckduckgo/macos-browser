//
//  MockFileStore.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class MockFileStore: FileStore {

    var persistedFiles: [URL: Data] = [:]

    func persist(_ data: Data, url: URL) -> Bool {
        persistedFiles[url] = data
        return true
    }

    func loadData(at url: URL) -> Data? {
        return persistedFiles[url]
    }

    func hasData(at url: URL) -> Bool {
        return persistedFiles[url] != nil
    }

    func remove(fileAtURL url: URL) {
        persistedFiles[url] = nil
    }

}
