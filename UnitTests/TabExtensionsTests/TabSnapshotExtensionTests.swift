//
//  TabSnapshotExtensionTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Navigation
import WebKit
import XCTest

@testable import DuckDuckGo_Privacy_Browser

class TabSnapshotExtensionTests: XCTestCase {
    var tabSnapshotExtension: TabSnapshotExtension!
    var mockWebViewSnapshotRenderer: MockWebViewSnapshotRenderer!
    var mockViewSnapshotRenderer: MockViewSnapshotRenderer!
    var mockTabSnapshotStore: MockTabSnapshotStore!
    var mockWebViewPublisher: PassthroughSubject<WKWebView, Never>!
    var mockContentPublisher: PassthroughSubject<Tab.TabContent, Never>!

    override func setUp() {
        super.setUp()
        mockWebViewSnapshotRenderer = MockWebViewSnapshotRenderer()
        mockViewSnapshotRenderer = MockViewSnapshotRenderer()
        mockTabSnapshotStore = MockTabSnapshotStore()
        mockWebViewPublisher = PassthroughSubject<WKWebView, Never>()
        mockContentPublisher = PassthroughSubject<Tab.TabContent, Never>()

        tabSnapshotExtension = TabSnapshotExtension(
            store: mockTabSnapshotStore,
            webViewSnapshotRenderer: mockWebViewSnapshotRenderer,
            viewSnapshotRenderer: mockViewSnapshotRenderer,
            webViewPublisher: mockWebViewPublisher.eraseToAnyPublisher(),
            contentPublisher: mockContentPublisher.eraseToAnyPublisher(),
            isBurner: false)
    }

    override func tearDown() {
        tabSnapshotExtension = nil
        mockWebViewSnapshotRenderer = nil
        mockViewSnapshotRenderer = nil
        mockTabSnapshotStore = nil
        super.tearDown()
    }

    @MainActor
    func testWhenSnapshotIsRestored_ThenRenderingIsSkippedAfterLoading() async {
        let uuid = UUID()
        let snapshot = NSImage()
        mockTabSnapshotStore.snapshots[uuid] = snapshot

        tabSnapshotExtension.setIdentifier(uuid)

        await Task.yield()

        let webView = WebView(frame: .zero, configuration: WKWebViewConfiguration())
        mockWebViewPublisher.send(webView)

        let content = Tab.TabContent.contentFromURL(URL.aURL, source: .ui)
        mockContentPublisher.send(content)

        let snapshot2 = NSImage()
        mockWebViewSnapshotRenderer.nextSnapshot = snapshot2

        await Task.yield()

        tabSnapshotExtension.didFinishLoad(with: URLRequest(url: URL.aURL), in: WKFrameInfo())

        await Task.yield()

        XCTAssertEqual(tabSnapshotExtension.snapshot, snapshot)
        XCTAssertNotEqual(tabSnapshotExtension.snapshot, snapshot2)
    }

    @MainActor
    func testWhenSnapshotIsNotRestored_ThenRenderingIsTriggeredAfterLoading() async {
        let uuid = UUID()
        let snapshot = NSImage()
        mockTabSnapshotStore.snapshots[uuid] = snapshot

        let webView = WebView(frame: .zero, configuration: WKWebViewConfiguration())
        mockWebViewPublisher.send(webView)

        let content = Tab.TabContent.contentFromURL(URL.aURL, source: .ui)
        mockContentPublisher.send(content)

        let snapshot2 = NSImage()
        mockWebViewSnapshotRenderer.nextSnapshot = snapshot2

        tabSnapshotExtension.didFinishLoad(with: URLRequest(url: URL.aURL), in: WKFrameInfo())

        await Task.yield()

        XCTAssertEqual(tabSnapshotExtension.snapshot, snapshot2)
        XCTAssertNotEqual(tabSnapshotExtension.snapshot, snapshot)
    }

    @MainActor
    func testWhenUserInteractsAndWebViewIsNotLoading_ThenSnapshotRenderingIsTriggered() async {
        let webView = WebView(frame: .zero, configuration: WKWebViewConfiguration())
        mockWebViewPublisher.send(webView)

        let content = Tab.TabContent.contentFromURL(URL.aURL, source: .ui)
        mockContentPublisher.send(content)

        let snapshot = NSImage()
        mockWebViewSnapshotRenderer.nextSnapshot = snapshot

        // Simulate user interaction with webView
        let event = NSEvent()
        tabSnapshotExtension.webView(webView, keyDown: event)

        // Simulate user unselected the tab and render the snapshot
        await tabSnapshotExtension.renderWebViewSnapshot()

        XCTAssertEqual(tabSnapshotExtension.snapshot, snapshot)
    }

    @MainActor
    func testWhenSnapshotDataUnchangedAndNoNewUserInteraction_ThenRedundantRenderingIsAvoided() async {
        let webView = WebView(frame: .zero, configuration: WKWebViewConfiguration())
        mockWebViewPublisher.send(webView)

        let content = Tab.TabContent.contentFromURL(URL.aURL, source: .ui)
        mockContentPublisher.send(content)

        let snapshot1 = NSImage()
        mockWebViewSnapshotRenderer.nextSnapshot = snapshot1

        // Simulate user interaction with webView
        let event = NSEvent()
        tabSnapshotExtension.webView(webView, keyDown: event)

        // Simulate user unselected the tab and render the snapshot
        await tabSnapshotExtension.renderWebViewSnapshot()

        XCTAssertEqual(tabSnapshotExtension.snapshot, snapshot1)

        let snapshot2 = NSImage()
        mockWebViewSnapshotRenderer.nextSnapshot = snapshot2

        // Simulate user unselected the tab and make sure the snapshot rendering is avoided
        await tabSnapshotExtension.renderWebViewSnapshot()

        XCTAssertNotEqual(tabSnapshotExtension.snapshot, snapshot2)
        XCTAssertEqual(tabSnapshotExtension.snapshot, snapshot1)
    }

    @MainActor
    func testWhenSnapshotIsRendered_ThenItIsPersistedCorrectly() async {
        let webView = WebView(frame: .zero, configuration: WKWebViewConfiguration())
        mockWebViewPublisher.send(webView)

        let content = Tab.TabContent.contentFromURL(URL.aURL, source: .ui)
        mockContentPublisher.send(content)

        let snapshot = NSImage()
        mockWebViewSnapshotRenderer.nextSnapshot = snapshot

        // Simulate user unselected the tab and make sure the snapshot rendering is avoided
        await tabSnapshotExtension.renderWebViewSnapshot()

        XCTAssert(mockTabSnapshotStore.persistedSnapshotIDs.count > 0)
    }

    @MainActor
    func testWhenSnapshotIsRenderedInBurnerTab_ThenItIsNotPersisted() async {
        tabSnapshotExtension = TabSnapshotExtension(
            store: mockTabSnapshotStore,
            webViewSnapshotRenderer: mockWebViewSnapshotRenderer,
            viewSnapshotRenderer: mockViewSnapshotRenderer,
            webViewPublisher: mockWebViewPublisher.eraseToAnyPublisher(),
            contentPublisher: mockContentPublisher.eraseToAnyPublisher(),
            isBurner: true)
        let webView = WebView(frame: .zero, configuration: WKWebViewConfiguration())
        mockWebViewPublisher.send(webView)

        let content = Tab.TabContent.contentFromURL(URL.aURL, source: .ui)
        mockContentPublisher.send(content)

        let snapshot = NSImage()
        mockWebViewSnapshotRenderer.nextSnapshot = snapshot

        // Simulate user unselected the tab and make sure the snapshot rendering is avoided
        await tabSnapshotExtension.renderWebViewSnapshot()

        XCTAssert(mockTabSnapshotStore.persistedSnapshotIDs.count == 0)
    }

}

fileprivate extension URL {

    static let aURL = URL(string: "https://example.com")!

}
