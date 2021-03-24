//
//  FaviconServiceMock.swift
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

import XCTest
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class FaviconServiceMock: FaviconService {

    var cachedFaviconsPublisher = PassthroughSubject<(host: String, favicon: NSImage), Never>()

    func fetchFavicon(_ faviconUrl: URL?, for host: String, isFromUserScript: Bool, completion: @escaping (NSImage?, Error?) -> Void) {
    }

    func getCachedFavicon(for host: String, mustBeFromUserScript: Bool) -> NSImage? {
        return nil
    }

    func cacheIfNeeded(favicon: NSImage, for host: String, isFromUserScript: Bool) {
    }

}
