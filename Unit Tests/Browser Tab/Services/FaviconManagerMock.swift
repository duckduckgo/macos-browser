//
//  FaviconManagerMock.swift
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

import BrowserServicesKit
import Combine
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class FaviconManagerMock: FaviconManagement {

    func loadFavicons() {}
    var areFaviconsLoaded: Bool { true }

    func handleFaviconLinks(_: [FaviconUserScript.FaviconLink], documentUrl _: URL, completion: @escaping (Favicon?) -> Void) {
        completion(nil)
    }

    func getCachedFavicon(for _: URL, sizeCategory _: Favicon.SizeCategory) -> Favicon? {
        nil
    }

    func getCachedFavicon(for _: String, sizeCategory _: Favicon.SizeCategory) -> Favicon? {
        nil
    }

    func burnExcept(
        fireproofDomains _: FireproofDomains,
        bookmarkManager _: BookmarkManager,
        completion: @escaping () -> Void) {
        completion()
    }

    func burnDomains(
        _: Set<String>,
        except _: BookmarkManager,
        completion: @escaping () -> Void) {
        completion()
    }

}
