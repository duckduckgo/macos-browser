//
//  ExternalURLHandlerTests.swift
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

final class ExternalURLHandlerTests: XCTestCase {

    static let smsUrl = URL(string: "sms://123123123123")!
    static let facetimeUrl = URL(string: "facetime://123123123123")!
    static let pageUrl = URL(string: "https://example.com")!
    static let nextPageUrl = URL(string: "https://example.com/page2.html")!

    func test_when_external_url_on_different_page_then_url_is_published() {

        let handler = ExternalURLHandler(collectionTimeMillis: 300)
        var cancellable: AnyCancellable?

        var e = expectation(description: "One sms handler fired")
        cancellable = handler.openExternalUrlPublisher.sink { _ in
            e.fulfill()
        }

        handler.handle(url: Self.smsUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: false)
        handler.handle(url: Self.smsUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: false)
        handler.handle(url: Self.smsUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: false)

        waitForExpectations(timeout: 3.0)

        // when the page changes we should get the next external url
        e = expectation(description: "Handler should be fired again")
        handler.handle(url: Self.facetimeUrl, onPage: Self.nextPageUrl, fromFrame: false, triggeredByUser: false)
        waitForExpectations(timeout: 1.0)

        cancellable?.cancel()
    }

    func test_when_external_url_on_page_presented_in_quick_succession_then_no_more_urls_published_on_same_page_unless_triggered_by_user() {

        let handler = ExternalURLHandler(collectionTimeMillis: 300)
        var cancellable: AnyCancellable?

        var count = 0
        cancellable = handler.openExternalUrlPublisher.sink { _ in
            count += 1
        }

        handler.handle(url: Self.smsUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: false)
        handler.handle(url: Self.smsUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: false)
        handler.handle(url: Self.smsUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: false)

        RunLoop.current.run(until: Date().addingTimeInterval(0.5)) // allow the debounce to happen
        XCTAssertEqual(1, count)

        // subsequent URLs should just be ignored
        handler.handle(url: Self.facetimeUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: true)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5)) // allow the debounce to happen
        XCTAssertEqual(2, count)

        cancellable?.cancel()
    }

    func test_when_external_url_on_page_presented_in_quick_succession_then_no_more_urls_published_on_same_page() {

        let handler = ExternalURLHandler(collectionTimeMillis: 300)
        var cancellable: AnyCancellable?

        var count = 0
        cancellable = handler.openExternalUrlPublisher.sink { _ in
            count += 1
        }

        handler.handle(url: Self.smsUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: false)
        handler.handle(url: Self.smsUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: false)
        handler.handle(url: Self.smsUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: false)

        RunLoop.current.run(until: Date().addingTimeInterval(0.5)) // allow the debounce to happen
        XCTAssertEqual(1, count)

        // subsequent URLs should just be ignored
        handler.handle(url: Self.facetimeUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: false)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5)) // allow the debounce to happen
        XCTAssertEqual(1, count)

        cancellable?.cancel()
    }

    func test_when_external_url_on_page_presented_in_quick_succession_then_single_url_is_published() {

        let handler = ExternalURLHandler(collectionTimeMillis: 300)
        var cancellable: AnyCancellable?

        var count = 0
        cancellable = handler.openExternalUrlPublisher.sink { _ in
            count += 1
        }

        handler.handle(url: Self.smsUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: false)
        handler.handle(url: Self.smsUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: false)
        handler.handle(url: Self.smsUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: false)

        RunLoop.current.run(until: Date().addingTimeInterval(0.5)) // allow the debounce to happen
        XCTAssertEqual(1, count)

        cancellable?.cancel()
    }

    func test_when_external_url_on_page_and_is_from_frame_then_url_is_not_published() {
        let handler = ExternalURLHandler(collectionTimeMillis: 0)
        var cancellable: AnyCancellable?
        cancellable = handler.openExternalUrlPublisher.sink { _ in
            cancellable?.cancel()
            XCTFail("Unexpected sink")
        }
        handler.handle(url: Self.smsUrl, onPage: Self.pageUrl, fromFrame: true, triggeredByUser: false)
    }

    func test_when_external_url_on_page_and_not_from_frame_then_url_is_published() {
        let urlsToPromptExpectation = expectation(description: "urlsToPromptExpectation")
        let handler = ExternalURLHandler(collectionTimeMillis: 0)
        var cancellable: AnyCancellable?
        cancellable = handler.openExternalUrlPublisher.sink { _ in
            urlsToPromptExpectation.fulfill()
        }
        handler.handle(url: Self.smsUrl, onPage: Self.pageUrl, fromFrame: false, triggeredByUser: false)
        wait(for: [urlsToPromptExpectation], timeout: 1.0, enforceOrder: false)
        cancellable?.cancel()
    }

}
