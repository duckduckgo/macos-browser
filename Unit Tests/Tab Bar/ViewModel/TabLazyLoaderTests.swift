//
//  TabLazyLoaderTests.swift
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

import XCTest
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class TabLazyLoaderDataSourceMock: TabLazyLoaderDataSource {
    var tabs: [Tab] = []
    var selectedTab: Tab?
    var selectedTabPublisher: AnyPublisher<Tab, Never> {
        _selectedTabSubject.eraseToAnyPublisher()
    }

    // swiftlint:disable:next identifier_name
    var _selectedTabSubject = PassthroughSubject<Tab, Never>()
}

// swiftlint:disable implicitly_unwrapped_optional
class TabLazyLoaderTests: XCTestCase {

    var dataSource: TabLazyLoaderDataSourceMock!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dataSource = TabLazyLoaderDataSourceMock()
    }

    func testWhenThereAreNoTabsThenLazyLoaderIsNotInstantiated() throws {
        dataSource.tabs = []
        XCTAssertNil(TabLazyLoader(dataSource: dataSource))
    }

    func testWhenThereAreNoURLTabsThenLazyLoaderIsNotInstantiated() throws {
        dataSource.tabs = [.init(content: .bookmarks), .init(content: .homePage)]
        XCTAssertNil(TabLazyLoader(dataSource: dataSource))
    }

    func testWhenThereIsOneURLTabAndItIsCurrentlySelectedThenLazyLoaderIsNotInstantiated() throws {
        let urlTab = Tab.init(content: .url("https://a.com".url!))
        dataSource.tabs = [.init(content: .bookmarks), .init(content: .homePage), urlTab]
        dataSource.selectedTab = urlTab
        XCTAssertNil(TabLazyLoader(dataSource: dataSource))
    }

    func testWhenThereIsOneURLTabAndItIsNotCurrentlySelectedThenLazyLoaderIsInstantiated() throws {
        let urlTab = Tab.init(content: .url("https://a.com".url!))
        dataSource.tabs = [.init(content: .bookmarks), .init(content: .homePage), urlTab]
        dataSource.selectedTab = .init(content: .bookmarks)
        XCTAssertNotNil(TabLazyLoader(dataSource: dataSource))
    }

    func testExample() throws {
        dataSource.tabs = [
            .init(content: .url("https://a.com".url!)),
            .init(content: .url("https://b.com".url!)),
            .init(content: .url("https://c.com".url!)),
            .init(content: .url("https://d.com".url!))
        ]
        let lazyLoader = TabLazyLoader(dataSource: dataSource)

        XCTAssertNotNil(lazyLoader)
    }

}
