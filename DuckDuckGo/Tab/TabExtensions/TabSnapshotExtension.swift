//
//  TabSnapshotExtension.swift
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

import Combine
import Common
import Foundation
import Navigation
import WebKit

final class TabSnapshotExtension {

    private var identifier: UUID?

    // Flag triggers rendering of snapshot after webview finishes loading
    private var renderSnapshotAfterLoad = true

    // Flag representes user interaction with the webview was detected
    private var userDidInteractWithWebsite = false

    // Flag is true if the extension restored the snapshot from storage
    private var didRestoreSnapshot = false

    private weak var webView: WebView?
    private var tabContent: Tab.TabContent?
    private var cancellables = Set<AnyCancellable>()

    private let store: TabSnapshotStoring
    private let webViewSnapshotRenderer: WebViewSnapshotRendering
    private let viewSnapshotRenderer: ViewSnapshotRendering

    init(store: TabSnapshotStoring = TabSnapshotStore(fileStore: NSApplication.shared.delegateTyped.fileStore),
         webViewSnapshotRenderer: WebViewSnapshotRendering = WebViewSnapshotRenderer(),
         viewSnapshotRenderer: ViewSnapshotRendering = ViewSnapshotRenderer(),
         webViewPublisher: some Publisher<WKWebView, Never>,
         contentPublisher: some Publisher<Tab.TabContent, Never>) {

        self.store = store
        self.webViewSnapshotRenderer = webViewSnapshotRenderer
        self.viewSnapshotRenderer = viewSnapshotRenderer

        webViewPublisher.sink { [weak self] webView in
            self?.webView = webView as? WebView
            self?.webView?.interactionEventsDelegate = self
        }.store(in: &cancellables)

        contentPublisher.sink { [weak self] tabContent in
            self?.tabContent = tabContent
        }.store(in: &cancellables)

        Task {
            await setIdentifier()
        }
    }

    deinit {
        if let identifier {
            store.clearSnapshot(tabID: identifier)
        }
    }

    @MainActor
    func setIdentifier(_ identifier: UUID? = nil) async {
        if let originalIdentifier = self.identifier {
            store.clearSnapshot(tabID: originalIdentifier)
        }

        guard let identifier else {
            // Create new identifier and render snapshot right after the first load
            self.identifier = UUID()
            renderSnapshotAfterLoad = true
            return
        }

        // Identifier exists, restore the snapshot
        self.identifier = identifier

        guard let image = await store.loadSnapshot(for: identifier) as? NSImage else {
            os_log("No snapshot restored", log: .tabSnapshots)
            return
        }

        snapshotData = SnapshotData(url: nil,
                                    image: image,
                                    webviewBoundsSize: NSSize.zero,
                                    isRestored: true)
        os_log("Snapshot restored", log: .tabSnapshots)

        renderSnapshotAfterLoad = false
    }

    // MARK: - Snapshot

    struct SnapshotData {
        var url: URL?
        var image: NSImage
        var webviewBoundsSize: NSSize
        var isRestored: Bool

        static func snapshotDataForRegularView(from image: NSImage) -> SnapshotData {
            return SnapshotData(url: nil, image: image, webviewBoundsSize: NSSize.zero, isRestored: false)
        }
    }

    private var snapshotData: SnapshotData? {
        didSet {
            if let snapshotData, let identifier {
                store.persistSnapshot(snapshotData.image, id: identifier)
            }
        }
    }

    @MainActor
    private func clearSnapshot() {
        snapshotData = nil
    }

    var snapshot: NSImage? {
        return snapshotData?.image
    }

    // MARK: - Snapshot rendered from web views

    @MainActor
    func renderWebViewSnapshot() async {
        guard let webView, let tabContent, let url = tabContent.url else {
            // Previews of native views are rendered in renderNativePreview()
            return
        }

        guard !webView.isLoading else {
            renderSnapshotAfterLoad = true
            return
        }

        // Avoid unnecessary rendering
        if let snapshotData,
           !userDidInteractWithWebsite,
           snapshotData.webviewBoundsSize == webView.bounds.size,
           snapshotData.url == url {
            os_log("Skipping snapshot rendering, it is already rendered. url: \(url)", log: .tabSnapshots)
            return
        }

        guard let snapshot = await webViewSnapshotRenderer.renderSnapshot(webView: webView) else {
            return
        }

        renderSnapshotAfterLoad = webView.isLoading
        userDidInteractWithWebsite = false

        snapshotData = SnapshotData(url: url,
                                    image: snapshot,
                                    webviewBoundsSize: webView.bounds.size,
                                    isRestored: false)
    }

    // MARK: - Snapshots rendered from regular views

    @MainActor
    func renderSnapshot(from view: NSView) async {
        guard let snapshot = await viewSnapshotRenderer.renderSnapshot(view: view) else {
            clearSnapshot()
            return
        }

        snapshotData = SnapshotData.snapshotDataForRegularView(from: snapshot)
        os_log("Snapshot of native page rendered", log: .tabSnapshots)
    }

}

extension TabSnapshotExtension: WebViewInteractionEventsDelegate {

    func webView(_ webView: WebView, mouseDown event: NSEvent) {
        userDidInteractWithWebsite = true
    }

    func webView(_ webView: WebView, keyDown event: NSEvent) {
        userDidInteractWithWebsite = true
    }

    func webView(_ webView: WebView, scrollWheel event: NSEvent) {
        userDidInteractWithWebsite = true
    }

}

extension TabSnapshotExtension: NSCodingExtension {

    private enum NSSecureCodingKeys {
        static let tabSnapshotIdentifier = "TabSnapshotIdentifier"
    }

    func awakeAfter(using decoder: NSCoder) {
        guard !didRestoreSnapshot else { return }

        guard let uuidString = decoder.decodeObject(of: NSString.self, forKey: NSSecureCodingKeys.tabSnapshotIdentifier),
              let identifier = UUID(uuidString: uuidString as String) else {
            os_log("Snapshot not available in the session state", log: .tabSnapshots)
            return
        }

        didRestoreSnapshot = true

        Task {
            await setIdentifier(identifier)
        }
    }

    func encode(using coder: NSCoder) {
        if let identifier {
            coder.encode(identifier.uuidString,
                         forKey: NSSecureCodingKeys.tabSnapshotIdentifier)
        }
    }

}

extension TabSnapshotExtension: NavigationResponder {

    @MainActor
    func willStart(_ navigation: Navigation) {
        if snapshotData?.isRestored == false {
            clearSnapshot()
        }

        userDidInteractWithWebsite = false
    }

    @MainActor
    func didFinishLoad(with request: URLRequest, in frame: WKFrameInfo) {
        if renderSnapshotAfterLoad {
            Task {
                await renderWebViewSnapshot()
            }
        }
    }

}

protocol TabSnapshotExtensionProtocol: AnyObject, NavigationResponder {

    var snapshot: NSImage? { get }

    func setIdentifier(_ identifier: UUID?) async
    func renderWebViewSnapshot() async
    func renderSnapshot(from view: NSView) async

}

extension TabSnapshotExtension: TabSnapshotExtensionProtocol, TabExtension {

    func getPublicProtocol() -> TabSnapshotExtensionProtocol { self }

}

extension TabExtensions {

    var tabSnapshots: TabSnapshotExtensionProtocol? { resolve(TabSnapshotExtension.self) }

}

extension Tab {

    var tabSnapshot: NSImage? {
        return self.tabSnapshots?.snapshot
    }

    // Called from the outside of extension when a tab is unselected
    func renderTabSnapshot() {
        Task {
            await self.tabSnapshots?.renderWebViewSnapshot()
        }
    }

}
