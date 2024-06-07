//
//  FaviconNullStore.swift
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
import Combine

final class FaviconNullStore: FaviconStoring {

    func loadFavicons() async throws -> [Favicon] {
        return []
    }

    func save(_ favicons: [Favicon]) async throws {
        ()
    }

    func removeFavicons(_ favicons: [Favicon]) async throws {
        ()
    }

    func loadFaviconReferences() async throws -> ([FaviconHostReference], [FaviconUrlReference]) {
        return ([], [])
    }

    func save(hostReference: FaviconHostReference) async throws {
        ()
    }

    func save(urlReference: FaviconUrlReference) async throws {
        ()
    }

    func remove(hostReferences: [FaviconHostReference]) async throws {
        ()
    }

    func remove(urlReferences: [FaviconUrlReference]) async throws {
        ()
    }

}
