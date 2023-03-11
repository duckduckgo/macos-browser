//
//  InternalUserDeciderStore.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

protocol InternalUserDeciderStoring {

    func save(isInternal: Bool) throws

    // Returns isInternal Bool value
    func load() throws -> Bool

}

enum InternalUserDeciderStoreError: Error {

    case savingFailed
    case loadingFailed
    case decodingFailed

}

final class InternalUserDeciderStore {

    static var fileURL: URL {
        return URL.sandboxApplicationSupportURL.appendingPathComponent("internalUserDeciderStore")
    }

    init(fileStore: FileStore) {
        store = fileStore
    }

    private var store: FileStore
}

extension InternalUserDeciderStore: InternalUserDeciderStoring {

    func save(isInternal: Bool) throws {
        guard store.persist(isInternal.data, url: Self.fileURL) else {
            throw InternalUserDeciderStoreError.savingFailed
        }
    }

    func load() throws -> Bool {
        guard let data = store.loadData(at: Self.fileURL) else {
            throw InternalUserDeciderStoreError.loadingFailed
        }

        guard let isInternal = Bool(data: data) else {
            throw InternalUserDeciderStoreError.decodingFailed
        }

        return isInternal
    }

}

fileprivate extension Bool {

    var data: Data {
        var data = Data()
        data.append(self ? 1 : 0)
        return data
    }

    init?(data: Data) {
        switch data.first {
        case 0: self = false
        case 1: self = true
        default: return nil
        }
    }
}
