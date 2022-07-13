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

    var isLazyLoadingInProgress: Bool = false

    var isUrl: Bool = true
    var url: URL? = "https://example.com".url
    var webViewFrame: CGRect = .zero

    var loadingFinishedSubject = PassthroughSubject<TabMock, Never>()
    lazy var loadingFinishedPublisher: AnyPublisher<TabMock, Never> = loadingFinishedSubject.eraseToAnyPublisher()

    func isNewer(than other: TabMock) -> Bool { isNewerClosure(other) }
    func reload() { reloadClosure(self) }

    var isNewerClosure: (TabMock) -> Bool = { _ in true }
    var reloadClosure: (TabMock) -> Void = { _ in }

    var selectedTimestamp: Date

    init(
        isUrl: Bool = true,
        url: URL? = "https://example.com".url,
        webViewFrame: CGRect = .zero,
        reloadExpectation: XCTestExpectation? = nil,
        selectedTimestamp: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.isUrl = isUrl
        self.url = url
        self.webViewFrame = webViewFrame
        self.selectedTimestamp = selectedTimestamp

        isNewerClosure = { [unowned self] other in
            self.selectedTimestamp > other.selectedTimestamp
        }

        reloadClosure = { tab in
            // instantly notify that loading has finished (or failed)
            DispatchQueue.main.async {
                reloadExpectation?.fulfill()
                tab.loadingFinishedSubject.send(tab)
            }
        }
    }

    static let mockUrl = TabMock()
    static let mockNotUrl = TabMock(isUrl: false, url: nil)
}

private final class TabLazyLoaderDataSourceMock: TabLazyLoaderDataSource {

    typealias Tab = TabMock

    var pinnedTabs: [Tab] = []
    var tabs: [Tab] = []
    var selectedTab: Tab?
    var selectedTabIndex: TabIndex?
    var selectedTabPublisher: AnyPublisher<Tab, Never> {
        selectedTabSubject.eraseToAnyPublisher()
    }

    var selectedTabSubject = PassthroughSubject<Tab, Never>()

    var isSelectedTabLoading: Bool = false
    var isSelectedTabLoadingPublisher: AnyPublisher<Bool, Never> {
        isSelectedTabLoadingSubject.eraseToAnyPublisher()
    }

    var isSelectedTabLoadingSubject = PassthroughSubject<Bool, Never>()
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
        waitForExpectations(timeout: 0.3)
        XCTAssertEqual(didFinishEvents.count, 1)
        XCTAssertEqual(try XCTUnwrap(didFinishEvents.first), true)
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
        waitForExpectations(timeout: 0.3)
        XCTAssertEqual(didFinishEvents.count, 1)
        XCTAssertEqual(try XCTUnwrap(didFinishEvents.first), true)
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
        waitForExpectations(timeout: 0.3)
        XCTAssertEqual(didFinishEvents.count, 0)
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
        waitForExpectations(timeout: 0.3)
        XCTAssertEqual(didFinishEvents.count, 1)
        XCTAssertEqual(try XCTUnwrap(didFinishEvents.first), true)
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
        waitForExpectations(timeout: 0.3)
        XCTAssertEqual(didFinishEvents.count, 1)
        XCTAssertEqual(try XCTUnwrap(didFinishEvents.first), true)
    }

    func testWhenTabNumberExceedsMaximumForLazyLoadingThenAdjacentTabsAreLoadedFirst() throws {
        let maxNumberOfLazyLoadedTabs = TabLazyLoader<TabLazyLoaderDataSourceMock>.Const.maxNumberOfLazyLoadedTabs
        let reloadExpectation = expectation(description: "TabMock.reload() called")
        reloadExpectation.expectedFulfillmentCount = maxNumberOfLazyLoadedTabs + 1

        var reloadedTabsIndices = [Int]()

        // add 2 * max number tabs, ordered by selected timestamp ascending
        for i in 0..<(2 * maxNumberOfLazyLoadedTabs) {
            let tab = TabMock(isUrl: true, url: "http://\(i).com".url!, selectedTimestamp: Date(timeIntervalSince1970: .init(i)))
            tab.reloadClosure = { tab in
                DispatchQueue.main.async {
                    reloadedTabsIndices.append(i)
                    tab.loadingFinishedSubject.send(tab)
                    reloadExpectation.fulfill()
                }
            }
            dataSource.tabs.append(tab)
        }

        // select tab #3, this will cause loading tabs adjacent to #3, and then from the end of the array (based on timestamp)
        dataSource.selectedTab = dataSource.tabs[3]
        dataSource.selectedTabIndex = .unpinned(3)

        let lazyLoader = TabLazyLoader(dataSource: dataSource)

        var didFinishEvents: [Bool] = []
        lazyLoader?.lazyLoadingDidFinishPublisher.sink(receiveValue: { didFinishEvents.append($0) }).store(in: &cancellables)

        // When
        lazyLoader?.scheduleLazyLoading()
        dataSource.selectedTab?.reload()

        // Then
        waitForExpectations(timeout: 0.3)
        XCTAssertEqual(didFinishEvents.count, 1)
        XCTAssertEqual(reloadedTabsIndices, [3, 4, 2, 5, 1, 6, 0, 7, 8, 9, 10, 39, 38, 37, 36, 35, 34, 33, 32, 31, 30])
    }

    /**
     * This test sets up 2 tabs suitable for lazy loading.
     * When the first one is reloaded, it artificially triggers currently selected tab reload.
     * This effectively pauses lazy loading and prevents the other tab from being reloaded
     * until currently selected tab is marked as done loading.
     */
    func testWhenSelectedTabIsLoadingThenLazyLoadingIsPaused() throws {
        var reloadedTabsUrls = [URL?]()

        let tabReloadClosure: (TabMock) -> Void = { tab in
            reloadedTabsUrls.append(tab.url)
            tab.loadingFinishedSubject.send(tab)
        }

        let oldTab = TabMock(isUrl: true, url: "http://old.com".url, selectedTimestamp: .init(timeIntervalSince1970: 0))
        let newTab = TabMock(isUrl: true, url: "http://new.com".url, selectedTimestamp: .init(timeIntervalSince1970: 1))

        oldTab.reloadClosure = tabReloadClosure
        newTab.reloadClosure = { [unowned self] tab in
            // mark currently selected tab as reloading, causing lazy loading to pause
            self.dataSource.isSelectedTabLoading = true
            self.dataSource.isSelectedTabLoadingSubject.send(true)
            tabReloadClosure(tab)
        }

        dataSource.tabs = [.mockNotUrl, newTab, oldTab]
        dataSource.selectedTab = dataSource.tabs.first

        let lazyLoader = TabLazyLoader(dataSource: dataSource)

        var didFinishEvents: [Bool] = []
        var isLazyLoadingPausedEvents: [Bool] = []

        lazyLoader?.lazyLoadingDidFinishPublisher.sink(receiveValue: { didFinishEvents.append($0) }).store(in: &cancellables)
        lazyLoader?.isLazyLoadingPausedPublisher.sink(receiveValue: { isLazyLoadingPausedEvents.append($0) }).store(in: &cancellables)

        // When
        lazyLoader?.scheduleLazyLoading()

        XCTAssertEqual(reloadedTabsUrls, [newTab.url])

        // unpause lazy loading here
        dataSource.isSelectedTabLoading = false
        dataSource.isSelectedTabLoadingSubject.send(false)

        // Then
        XCTAssertEqual(reloadedTabsUrls, [newTab.url, oldTab.url])
        XCTAssertEqual(didFinishEvents.count, 1)
        XCTAssertEqual(isLazyLoadingPausedEvents, [false, true, false])
        XCTAssertEqual(try XCTUnwrap(didFinishEvents.first), true)
    }

}
