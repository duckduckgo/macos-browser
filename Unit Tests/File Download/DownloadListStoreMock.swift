//
//  DownloadListStoreMock.swift
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

final class DownloadListStoreMock: DownloadListStoring {

    var fetchBlock: ((Date, @escaping (Result<[DownloadListItem], Error>) -> Void) -> Void)?
    func fetch(clearingItemsOlderThan date: Date, completionHandler: @escaping (Result<[DownloadListItem], Error>) -> Void) {
        fetchBlock?(date, completionHandler)
    }

    var saveBlock: ((DownloadListItem, ((Error?) -> Void)?) -> Void)?
    func save(_ item: DownloadListItem, completionHandler: ((Error?) -> Void)?) {
        saveBlock?(item, completionHandler)
    }

    var removeBlock: ((DownloadListItem, ((Error?) -> Void)?) -> Void)?
    func remove(_ item: DownloadListItem, completionHandler: ((Error?) -> Void)?) {
        removeBlock?(item, completionHandler)
    }

    var clearBlock: ((Date, ((Error?) -> Void)?) -> Void)?
    func clear(itemsOlderThan date: Date, completionHandler: ((Error?) -> Void)?) {
        clearBlock?(date, completionHandler)
    }

    var syncBlock: (() -> Void)?
    func sync() {
        syncBlock?()
    }

}
