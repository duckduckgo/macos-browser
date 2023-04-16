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
import BrowserServicesKit

final class InternalUserDeciderStore: InternalUserStoring {

    private let store: FileStore

    static var fileURL: URL {
        return URL.sandboxApplicationSupportURL.appendingPathComponent("internalUserDeciderStore")
    }

    init(fileStore: FileStore) {
        store = fileStore
        isInternalUser = store.load(url: Self.fileURL)
    }

    var isInternalUser: Bool {
        didSet {
            // Optimisation below prevents from 2 unnecesary events:
            // 1) Rewriting of the file with the same value
            // 2) Also from initial saving of the false value to the disk
            // which is unnecessary since it is the default value.
            // It helps to load the app for majority of users (external) faster
            if oldValue != isInternalUser {
                save(isInternal: isInternalUser)
            }
        }
    }

    private func save(isInternal: Bool) {
        guard store.persist(isInternal.data, url: Self.fileURL) else {
            assertionFailure()
            return
        }
    }
}

fileprivate extension FileStore {
    func load(url: URL) -> Bool {
        guard let data = loadData(at: url) else {
            return false
        }

        guard let boolValue = Bool(data: data) else {
            return false
        }

        return boolValue
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
