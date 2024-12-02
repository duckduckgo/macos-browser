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
import os.log

final class TabSnapshotExtension {

    @MainActor private(set) var identifier = UUID()

    // Flag triggers rendering of snapshot after webview finishes loading
    @MainActor private var renderSnapshotAfterLoad = true

    // Flag representes user interaction with the webview was detected
    @MainActor private var userDidInteractWithWebsite = false

    // Flag is true if the extension restored the snapshot from storage
    @MainActor private var didRestoreSnapshot = false

    private weak var webView: WebView?
    private var tabContent: Tab.TabContent?
    private var cancellables = Set<AnyCancellable>()
    private var isBurner: Bool

    private let store: TabSnapshotStoring
    private let webViewSnapshotRenderer: WebViewSnapshotRendering
    private let viewSnapshotRenderer: ViewSnapshotRendering

    init(store: TabSnapshotStoring = TabSnapshotStore(fileStore: NSApplication.shared.delegateTyped.fileStore),
         webViewSnapshotRenderer: WebViewSnapshotRendering = WebViewSnapshotRenderer(),
         viewSnapshotRenderer: ViewSnapshotRendering = ViewSnapshotRenderer(),
         webViewPublisher: some Publisher<WKWebView, Never>,
         contentPublisher: some Publisher<Tab.TabContent, Never>,
         isBurner: Bool) {

        self.store = store
        self.webViewSnapshotRenderer = webViewSnapshotRenderer
        self.viewSnapshotRenderer = viewSnapshotRenderer
        self.isBurner = isBurner

        webViewPublisher.sink { [weak self] webView in
            self?.webView = webView as? WebView
            self?.webView?.interactionEventsDelegate = self
        }.store(in: &cancellables)

        contentPublisher.sink { [weak self] tabContent in
            self?.tabContent = tabContent
        }.store(in: &cancellables)
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        webView?.interactionEventsDelegate = nil
        webView = nil

        store.clearSnapshot(tabID: identifier)
    }

    @MainActor
    // Method for changing the identifier in case it was successfully restored
    func setIdentifier(_ identifier: UUID) {
        store.clearSnapshot(tabID: self.identifier)

        self.identifier = identifier

        // Restore the snapshot
        Task { [weak self] in
            guard let self = self else { return }

            guard let image = await self.store.loadSnapshot(for: identifier) as NSImage? else {
                Logger.tabSnapshots.debug("No snapshot restored")
                return
            }

            guard self.snapshotData == nil else {
                // Snapshot has been rendered in the meantime
                return
            }

            self.snapshotData = SnapshotData(url: nil,
                                             image: image,
                                             webviewBoundsSize: NSSize.zero,
                                             isRestored: true)
            Logger.tabSnapshots.debug("Snapshot restored")

            self.renderSnapshotAfterLoad = false
        }
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

    @MainActor
    private var snapshotData: SnapshotData? {
        didSet {
            if let snapshotData, !snapshotData.isRestored {
                storeSnapshot(snapshotData.image, identifier: identifier)
            }
        }
    }

    @MainActor
    private func clearSnapshot() {
        snapshotData = nil
    }

    private func storeSnapshot(_ snapshot: NSImage, identifier: UUID) {
        guard !isBurner else {
            return
        }

        store.persistSnapshot(snapshot, id: identifier)
    }

    @MainActor
    var snapshot: NSImage? {
        return snapshotData?.image
    }

    // MARK: - Snapshot rendered from web views

    @MainActor
    func renderWebViewSnapshot() async {
        guard let webView, let tabContent,
              let url = tabContent.userEditableUrl,
              url.navigationalScheme != .duck || url == .onboarding else {
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
            Logger.tabSnapshots.debug("Skipping snapshot rendering, it is already rendered. url: \(url)")
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
        Logger.tabSnapshots.debug("Snapshot of native page rendered")
    }

}

extension TabSnapshotExtension: WebViewInteractionEventsDelegate {

    @MainActor(unsafe)
    func webView(_ webView: WebView, mouseDown event: NSEvent) {
        userDidInteractWithWebsite = true
    }

    @MainActor(unsafe)
    func webView(_ webView: WebView, keyDown event: NSEvent) {
        userDidInteractWithWebsite = true
    }

    @MainActor(unsafe)
    func webView(_ webView: WebView, scrollWheel event: NSEvent) {
        userDidInteractWithWebsite = true
    }

}

extension TabSnapshotExtension: NSCodingExtension {

    private enum NSSecureCodingKeys {
        static let tabSnapshotIdentifier = "TabSnapshotIdentifier"
    }

    @MainActor
    func awakeAfter(using decoder: NSCoder) {
        guard !didRestoreSnapshot else { return }

        guard let uuidString = decoder.decodeObject(of: NSString.self, forKey: NSSecureCodingKeys.tabSnapshotIdentifier),
              let identifier = UUID(uuidString: uuidString as String) else {
            Logger.tabSnapshots.debug("Snapshot not available in the session state")
            return
        }

        didRestoreSnapshot = true

        setIdentifier(identifier)
    }

    @MainActor
    func encode(using coder: NSCoder) {
        coder.encode(identifier.uuidString,
                     forKey: NSSecureCodingKeys.tabSnapshotIdentifier)
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
            Task { [weak self] in
                await self?.renderWebViewSnapshot()
            }
        }
    }

}

protocol TabSnapshotExtensionProtocol: AnyObject, NavigationResponder {

    var snapshot: NSImage? { get }
    var identifier: UUID { get }

    func setIdentifier(_ identifier: UUID)
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

    var tabSnapshotIdentifier: UUID? {
        return self.tabSnapshots?.identifier
    }

    // Called from the outside of extension when a tab is unselected
    func renderTabSnapshot() {
        Task { [weak self] in
            await self?.tabSnapshots?.renderWebViewSnapshot()
        }
    }

}
