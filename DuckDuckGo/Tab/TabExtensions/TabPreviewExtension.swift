//
//  TabPreviewExtension.swift
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

// 1. Use from the outside
// 2. Finish the inside
// 3. Fix timing of the preview

final class TabPreviewExtension {

    private(set) var preview: NSImage?

    private var cancellables = Set<AnyCancellable>()
    private weak var webView: WKWebView?

    init(webViewPublisher: some Publisher<WKWebView, Never>) {
        webViewPublisher.sink { [weak self] webView in
            self?.webView = webView
        }.store(in: &cancellables)
    }

    @MainActor
    func generatePreview() {
        dispatchPrecondition(condition: .onQueue(.main))

        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = false
        config.snapshotWidth = NSNumber(floatLiteral: TabPreviewWindowController.Size.width.rawValue)

        guard let webView else {
            assertionFailure("WebView is missing")
            return
        }

        webView.takeSnapshot(with: config) { [weak self] image, _ in
            guard let image = image else {
                os_log("BrowserTabViewController: failed to create a snapshot of webView", type: .error)
                return
            }
            self?.preview = image
        }

        //TODO: remove
        os_log("generatePreview \(webView.url)", type: .info)
    }

    @MainActor
    private func clearPreview() {
        preview = nil
    }

}

extension TabPreviewExtension: NSCodingExtension {

    private enum NSSecureCodingKeys {
        static let tabPreview = "tabPreview"
    }

    func awakeAfter(using decoder: NSCoder) {
        //TODO: Uncomment
//        preview = decoder.decodeObject(of: [NSImage.self], forKey: NSSecureCodingKeys.tabPreview) as? NSImage
    }

    func encode(using coder: NSCoder) {
        coder.encode(preview, forKey: NSSecureCodingKeys.tabPreview)
    }

}

extension TabPreviewExtension: NavigationResponder {

    @MainActor
    func willStart(_ navigation: Navigation) {
        clearPreview()
    }

    @MainActor
    func didFinishLoad(with request: URLRequest, in frame: WKFrameInfo) {
        generatePreview()
    }

}

protocol TabPreviewExtensionProtocol: AnyObject, NavigationResponder {

    var preview: NSImage? { get }
    func generatePreview()

}

extension TabPreviewExtension: TabPreviewExtensionProtocol, TabExtension {
    func getPublicProtocol() -> TabPreviewExtensionProtocol { self }
}

extension TabExtensions {
    var tabPreviews: TabPreviewExtensionProtocol? { resolve(TabPreviewExtension.self) }
}

extension Tab {

    var tabPreview: NSImage? {
        return self.tabPreviews?.preview
    }

    // Called from the outside of extension when a tab is switched
    func generateTabPreview() {
        self.tabPreviews?.generatePreview()
    }

}
