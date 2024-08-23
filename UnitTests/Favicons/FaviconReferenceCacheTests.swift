//
//  FaviconReferenceCacheTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import XCTest

@testable import DuckDuckGo_Privacy_Browser

class FaviconReferenceCacheTests: XCTestCase {

    @MainActor
    func testWhenFaviconUrlIsAddedToHostCache_ThenFaviconUrlIsUsedForWholeDomain() {
        let referenceCache = FaviconReferenceCache(faviconStoring: FaviconStoringMock())
        let burningExpectation = expectation(description: "Loading")
        referenceCache.loadReferences { _ in
            burningExpectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)

        XCTAssert(URL.aDocumentUrl1.host == URL.aDocumentUrl2.host)

        referenceCache.insert(faviconUrls: (URL.aFaviconUrl1, URL.aFaviconUrl1), documentUrl: URL.aDocumentUrl1)
        XCTAssertEqual(URL.aFaviconUrl1, referenceCache.getFaviconUrl(for: URL.aDocumentUrl1.host!, sizeCategory: .small))
        XCTAssertEqual(URL.aFaviconUrl1, referenceCache.getFaviconUrl(for: URL.aDocumentUrl1, sizeCategory: .small))
        XCTAssertEqual(URL.aFaviconUrl1, referenceCache.getFaviconUrl(for: URL.aDocumentUrl2, sizeCategory: .small))
        XCTAssertNil(referenceCache.getFaviconUrl(for: URL.aDocumentUrl3, sizeCategory: .small))
    }

    @MainActor
    func testWhenFaviconUrlIsAddedToRefeceneCache_ThenFaviconUrlIsUsedForTheSpecialUrl() {
        let referenceCache = FaviconReferenceCache(faviconStoring: FaviconStoringMock())
        let burningExpectation = expectation(description: "Loading")
        referenceCache.loadReferences { _ in
            burningExpectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)

        XCTAssertEqual(URL.aDocumentUrl1.host, URL.aDocumentUrl2.host)

        referenceCache.insert(faviconUrls: (URL.aFaviconUrl1, URL.aFaviconUrl1), documentUrl: URL.aDocumentUrl1)
        XCTAssertEqual(URL.aFaviconUrl1, referenceCache.getFaviconUrl(for: URL.aDocumentUrl1.host!, sizeCategory: .small))
        XCTAssertEqual(URL.aFaviconUrl1, referenceCache.getFaviconUrl(for: URL.aDocumentUrl1, sizeCategory: .small))
        XCTAssertEqual(URL.aFaviconUrl1, referenceCache.getFaviconUrl(for: URL.aDocumentUrl2, sizeCategory: .small))
        XCTAssertNil(referenceCache.getFaviconUrl(for: URL.aDocumentUrl3, sizeCategory: .small))

        referenceCache.insert(faviconUrls: (URL.aFaviconUrl2, URL.aFaviconUrl2), documentUrl: URL.aDocumentUrl2)
        XCTAssertEqual(URL.aFaviconUrl1, referenceCache.getFaviconUrl(for: URL.aDocumentUrl1.host!, sizeCategory: .small))
        XCTAssertEqual(URL.aFaviconUrl1, referenceCache.getFaviconUrl(for: URL.aDocumentUrl1, sizeCategory: .small))
        XCTAssertEqual(URL.aFaviconUrl2, referenceCache.getFaviconUrl(for: URL.aDocumentUrl2, sizeCategory: .small))
        XCTAssertNil(referenceCache.getFaviconUrl(for: URL.aDocumentUrl3, sizeCategory: .small))
    }

    @MainActor
    func testWhenUrlIsPartOfHostCacheAndReferenceCache_ThenOldEntryMustBeInvalidated() {
        let referenceCache = FaviconReferenceCache(faviconStoring: FaviconStoringMock())
        let burningExpectation = expectation(description: "Loading")
        referenceCache.loadReferences { _ in
            burningExpectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)

        XCTAssertEqual(URL.aFaviconUrl1.host, URL.aFaviconUrl2.host)

        referenceCache.insert(faviconUrls: (URL.aFaviconUrl1, URL.aFaviconUrl1), documentUrl: URL.aDocumentUrl1)
        XCTAssertEqual(URL.aFaviconUrl1, referenceCache.getFaviconUrl(for: URL.aDocumentUrl1.host!, sizeCategory: .small))

        referenceCache.insert(faviconUrls: (URL.aFaviconUrl2, URL.aFaviconUrl2), documentUrl: URL.aDocumentUrl2)
        XCTAssertEqual(URL.aFaviconUrl1, referenceCache.getFaviconUrl(for: URL.aDocumentUrl1.host!, sizeCategory: .small))
        XCTAssertEqual(URL.aFaviconUrl2, referenceCache.getFaviconUrl(for: URL.aDocumentUrl2, sizeCategory: .small))

        referenceCache.insert(faviconUrls: (URL.aFaviconUrl1, URL.aFaviconUrl1), documentUrl: URL.aDocumentUrl2)
        XCTAssertEqual(URL.aFaviconUrl1, referenceCache.getFaviconUrl(for: URL.aDocumentUrl1.host!, sizeCategory: .small))
        XCTAssertEqual(URL.aFaviconUrl1, referenceCache.getFaviconUrl(for: URL.aDocumentUrl2, sizeCategory: .small))
    }
}

private extension URL {

    static let aFaviconUrl1 = URL(string: "https://fav.com/fav.ico")!
    static let aDocumentUrl1 = URL(string: "https://fav.com/index.html")!

    static let aFaviconUrl2 = URL(string: "https://fav.com/fav-specialized.ico")!
    static let aDocumentUrl2 = URL(string: "https://fav.com/special/site/index.html")!

    static let aDocumentUrl3 = URL(string: "https://duckduckgo.com/")!

}
