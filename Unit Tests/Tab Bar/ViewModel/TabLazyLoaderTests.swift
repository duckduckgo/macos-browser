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

private final class TabMock: LazyLoadable {
    var isUrl: Bool = true
    var url: URL? = "https://example.com".url
    var webViewFrame: CGRect = .zero

    var loadingFinishedSubject = PassthroughSubject<TabMock, Never>()
    lazy var loadingFinishedPublisher: AnyPublisher<TabMock, Never> = loadingFinishedSubject.eraseToAnyPublisher()

    func isNewer(than other: TabMock) -> Bool { isNewerClosure(other) }
    func reload() { reloadClosure() }

    var isNewerClosure: (TabMock) -> Bool = { _ in true }
    var reloadClosure: () -> Void = {}

    init(
        isUrl: Bool = true,
        url: URL? = "https://example.com".url,
        webViewFrame: CGRect = .zero,
        reloadExpectation: XCTestExpectation? = nil
    ) {
        self.isUrl = isUrl
        self.url = url
        self.webViewFrame = webViewFrame

        reloadClosure = { [unowned self] in
            // instantly notify that loading has finished (or failed)
            reloadExpectation?.fulfill()
            self.loadingFinishedSubject.send(self)
        }
    }

    static let mockUrl = TabMock()
    static let mockNotUrl = TabMock(isUrl: false, url: nil)
}

private final class TabLazyLoaderDataSourceMock: TabLazyLoaderDataSource {
    typealias Tab = TabMock

    var tabs: [Tab] = []
    var selectedTab: Tab?
    var selectedTabPublisher: AnyPublisher<Tab, Never> {
        selectedTabSubject.eraseToAnyPublisher()
    }

    var selectedTabSubject = PassthroughSubject<Tab, Never>()
}

class TabLazyLoaderTests: XCTestCase {

    // swiftlint:disable implicitly_unwrapped_optional
    private var dataSource: TabLazyLoaderDataSourceMock!
    var cancellables = Set<AnyCancellable>()

    override func setUpWithError() throws {
        try super.setUpWithError()
        dataSource = TabLazyLoaderDataSourceMock()
        cancellables.removeAll()
    }

    func testWhenThereAreNoTabsThenLazyLoaderIsNotInstantiated() throws {
        dataSource.tabs = []
        XCTAssertNil(TabLazyLoader(dataSource: dataSource))
    }

    func testWhenThereAreNoUrlTabsThenLazyLoaderIsNotInstantiated() throws {
        dataSource.tabs = [.mockNotUrl, .mockNotUrl]
        XCTAssertNil(TabLazyLoader(dataSource: dataSource))
    }

    func testWhenThereIsOneUrlTabAndItIsCurrentlySelectedThenLazyLoaderIsNotInstantiated() throws {
        let urlTab = TabMock.mockUrl
        dataSource.tabs = [.mockNotUrl, .mockNotUrl, urlTab]
        dataSource.selectedTab = urlTab
        XCTAssertNil(TabLazyLoader(dataSource: dataSource))
    }

    func testWhenThereIsOneUrlTabAndItIsNotCurrentlySelectedThenLazyLoaderIsInstantiated() throws {
        let notUrlTab = TabMock.mockUrl
        dataSource.tabs = [.mockNotUrl, notUrlTab, .mockUrl]
        dataSource.selectedTab = notUrlTab
        XCTAssertNotNil(TabLazyLoader(dataSource: dataSource))
    }

    func testWhenThereIsNoSelectedTabThenLazyLoadingIsSkipped() throws {
        dataSource.tabs = [.mockUrl]
        dataSource.selectedTab = nil

        let lazyLoader = TabLazyLoader(dataSource: dataSource)

        var didFinishEvents: [Bool] = []
        lazyLoader?.lazyLoadingDidFinishPublisher
            .sink(receiveValue: { value in
                didFinishEvents.append(value)
            })
            .store(in: &cancellables)

        lazyLoader?.scheduleLazyLoading()

        XCTAssertEqual(didFinishEvents.count, 1)
        XCTAssertEqual(try XCTUnwrap(didFinishEvents.first), false)
    }

    func testWhenSelectedTabIsNotUrlThenLazyLoadingStartsImmediately() throws {
        let reloadExpectation = expectation(description: "TabMock.reload() called")
        reloadExpectation.expectedFulfillmentCount = 2

        dataSource.tabs = [
            .mockNotUrl,
            TabMock.init(isUrl: true, reloadExpectation: reloadExpectation),
            TabMock.init(isUrl: true, reloadExpectation: reloadExpectation)
        ]
        dataSource.selectedTab = dataSource.tabs.first

        let lazyLoader = TabLazyLoader(dataSource: dataSource)

        var didFinishEvents: [Bool] = []
        lazyLoader?.lazyLoadingDidFinishPublisher.sink(receiveValue: { didFinishEvents.append($0) }).store(in: &cancellables)

        // When
        lazyLoader?.scheduleLazyLoading()

        // Then
        XCTAssertEqual(didFinishEvents.count, 1)
        XCTAssertEqual(try XCTUnwrap(didFinishEvents.first), true)
        waitForExpectations(timeout: 0.3)
    }

    func testThatLazyLoadingStartsAfterCurrentUrlTabFinishesLoading() throws {
        let reloadExpectation = expectation(description: "TabMock.reload() called")
        reloadExpectation.expectedFulfillmentCount = 2

        let selectedUrlTab = TabMock.mockUrl

        dataSource.tabs = [
            selectedUrlTab,
            TabMock.init(isUrl: true, reloadExpectation: reloadExpectation),
            TabMock.init(isUrl: true, reloadExpectation: reloadExpectation)
        ]
        dataSource.selectedTab = dataSource.tabs.first

        let lazyLoader = TabLazyLoader(dataSource: dataSource)

        var didFinishEvents: [Bool] = []
        lazyLoader?.lazyLoadingDidFinishPublisher.sink(receiveValue: { didFinishEvents.append($0) }).store(in: &cancellables)

        // When
        lazyLoader?.scheduleLazyLoading()
        selectedUrlTab.reload()

        // Then
        XCTAssertEqual(didFinishEvents.count, 1)
        XCTAssertEqual(try XCTUnwrap(didFinishEvents.first), true)
        waitForExpectations(timeout: 0.3)
    }

    func testThatLazyLoadingDoesNotStartIfCurrentUrlTabDoesNotFinishLoading() throws {
        let reloadExpectation = expectation(description: "TabMock.reload() called")
        reloadExpectation.isInverted = true

        dataSource.tabs = [
            .mockUrl,
            TabMock.init(isUrl: true, reloadExpectation: reloadExpectation),
            TabMock.init(isUrl: true, reloadExpectation: reloadExpectation)
        ]
        dataSource.selectedTab = dataSource.tabs.first

        let lazyLoader = TabLazyLoader(dataSource: dataSource)

        var didFinishEvents: [Bool] = []
        lazyLoader?.lazyLoadingDidFinishPublisher.sink(receiveValue: { didFinishEvents.append($0) }).store(in: &cancellables)

        // When
        lazyLoader?.scheduleLazyLoading()

        // Then
        XCTAssertEqual(didFinishEvents.count, 0)
        waitForExpectations(timeout: 0.3)
    }

    func testThatLazyLoadingStopsAfterLoadingMaximumNumberOfTabs() throws {
        let maxNumberOfLazyLoadedTabs = TabLazyLoader<TabLazyLoaderDataSourceMock>.Const.maxNumberOfLazyLoadedTabs
        let reloadExpectation = expectation(description: "TabMock.reload() called")
        reloadExpectation.expectedFulfillmentCount = maxNumberOfLazyLoadedTabs

        dataSource.tabs = [.mockNotUrl]
        for _ in 0..<(2 * maxNumberOfLazyLoadedTabs) {
            dataSource.tabs.append(TabMock.init(isUrl: true, reloadExpectation: reloadExpectation))
        }
        dataSource.selectedTab = dataSource.tabs.first

        let lazyLoader = TabLazyLoader(dataSource: dataSource)

        var didFinishEvents: [Bool] = []
        lazyLoader?.lazyLoadingDidFinishPublisher.sink(receiveValue: { didFinishEvents.append($0) }).store(in: &cancellables)

        // When
        lazyLoader?.scheduleLazyLoading()

        // Then
        XCTAssertEqual(didFinishEvents.count, 1)
        XCTAssertEqual(try XCTUnwrap(didFinishEvents.first), true)
        waitForExpectations(timeout: 0.3)
    }

    func testThatLazyLoadingSkipsTabsSelectedInCurrentSession() throws {
        let reloadExpectation = expectation(description: "TabMock.reload() called")
        reloadExpectation.expectedFulfillmentCount = 2

        let selectedUrlTab = TabMock.mockUrl

        dataSource.tabs = [
            selectedUrlTab,
            TabMock.init(isUrl: true, reloadExpectation: reloadExpectation),
            TabMock.init(isUrl: true, reloadExpectation: reloadExpectation),
            TabMock.init(isUrl: true, reloadExpectation: reloadExpectation),
            TabMock.init(isUrl: true, reloadExpectation: reloadExpectation),
            TabMock.init(isUrl: true, reloadExpectation: reloadExpectation)
        ]
        dataSource.selectedTab = selectedUrlTab

        let lazyLoader = TabLazyLoader(dataSource: dataSource)

        var didFinishEvents: [Bool] = []
        lazyLoader?.lazyLoadingDidFinishPublisher.sink(receiveValue: { didFinishEvents.append($0) }).store(in: &cancellables)

        // When
        lazyLoader?.scheduleLazyLoading()

        dataSource.selectedTabSubject.send(dataSource.tabs[1])
        dataSource.selectedTabSubject.send(dataSource.tabs[4])
        dataSource.selectedTabSubject.send(dataSource.tabs[5])

        selectedUrlTab.reload()

        // Then
        XCTAssertEqual(didFinishEvents.count, 1)
        XCTAssertEqual(try XCTUnwrap(didFinishEvents.first), true)
        waitForExpectations(timeout: 0.3)
    }
}
