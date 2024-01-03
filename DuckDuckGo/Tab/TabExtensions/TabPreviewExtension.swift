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

final class TabPreviewExtension {

    struct PreviewData {
        var url: URL
        var scrollPosition: CGFloat
        var image: NSImage
    }

    private var previewData: PreviewData?
    private var generatePreviewAfterLoad = false

    var preview: NSImage? {
        return previewData?.image
    }

    private var cancellables = Set<AnyCancellable>()
    private weak var webView: WKWebView?
    private var tabContent: Tab.TabContent?

    init(webViewPublisher: some Publisher<WKWebView, Never>, contentPublisher: some Publisher<Tab.TabContent, Never>) {
        webViewPublisher.sink { [weak self] webView in
            self?.webView = webView
        }.store(in: &cancellables)

        contentPublisher.sink { [weak self] tabContent in
            self?.tabContent = tabContent
        }.store(in: &cancellables)
    }

    @MainActor
    func generatePreview() async {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let webView else {
            assertionFailure("WebView is missing")
            return
        }

        guard let url = webView.url else { return }

        guard let tabContent, tabContent.isUrl else {
            //TODO: Generate preview from SwiftUI views
            return
        }

        // Avoid unnecessary generations
        let scrollPosition = try? await getScrollPosition()
        if let previewData, previewData.url == url, previewData.scrollPosition == scrollPosition {
            // Preview is already generated
            return
        }

        let configuration = WKSnapshotConfiguration.makeConfiguration()
        webView.takeSnapshot(with: configuration) { [weak self] image, _ in
            guard let image = image else {
                os_log("TabPreviewExtension: failed to create a snapshot of webView", type: .error)
                return
            }
            self?.generatePreviewAfterLoad = false
            self?.previewData = PreviewData(url: url, scrollPosition: 0, image: image)

            //TODO: remove
            os_log("!preview generated \(webView.url)", type: .info)
        }


    }

    @MainActor
    private func getScrollPosition() async throws -> CGFloat? {
        guard let webView else {
            assertionFailure("WebView is missing")
            return nil
        }

        do {
            let result = try await webView.evaluateJavaScript("window.scrollY")
            if let scrollPosition = result as? CGFloat {
                return scrollPosition
            }
            return nil
        } catch {
            throw error
        }
    }

    @MainActor
    private func clearPreview() {
        previewData = nil
    }

}

extension TabPreviewExtension: NSCodingExtension {

    private enum NSSecureCodingKeys {
        static let tabPreviewImage = "tabPreviewImage"
        static let tabPreviewUrl = "tabPreviewUrl"
        static let tabPreviewScrollPosition = "tabPreviewScrollPosition"
    }

    func awakeAfter(using decoder: NSCoder) {
        //TODO: Decoding and encoding
//        guard let urlString = decoder.decodeObject(forKey: NSSecureCodingKeys.tabPreviewUrl) as? NSString,
//              let url = URL(string: urlString as String),
//              let image = decoder.decodeObject(forKey: NSSecureCodingKeys.tabPreviewImage) as? NSImage else {
//            return
//        }
//        let scrollPosition = CGFloat(decoder.decodeDouble(forKey: NSSecureCodingKeys.tabPreviewScrollPosition))
//
//        previewData = PreviewData(url: url, scrollPosition: scrollPosition, image: image)
        //TODO: If we don't have data
        generatePreviewAfterLoad = true
    }

    func encode(using coder: NSCoder) {
//        if let previewData {
//            coder.encode(previewData.url.absoluteString as NSString, forKey: NSSecureCodingKeys.tabPreviewUrl)
//            coder.encode(Double(previewData.scrollPosition), forKey: NSSecureCodingKeys.tabPreviewScrollPosition)
//            coder.encode(previewData.image, forKey: NSSecureCodingKeys.tabPreviewImage)
//        }
    }

}

extension TabPreviewExtension: NavigationResponder {

    @MainActor
    func willStart(_ navigation: Navigation) {
        clearPreview()
    }

    @MainActor
    func didFinishLoad(with request: URLRequest, in frame: WKFrameInfo) {
        if generatePreviewAfterLoad {
            Task {
                await generatePreview()
            }
        }
    }

}

protocol TabPreviewExtensionProtocol: AnyObject, NavigationResponder {

    var preview: NSImage? { get }
    func generatePreview() async

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
        Task { [weak self] in
            await self?.tabPreviews?.generatePreview()
        }
    }

}

fileprivate extension WKSnapshotConfiguration {

    static func makeConfiguration() -> WKSnapshotConfiguration {
        let configuration = WKSnapshotConfiguration()
        configuration.afterScreenUpdates = false
        configuration.snapshotWidth = NSNumber(floatLiteral: TabPreviewWindowController.Size.width.rawValue)
        return configuration
    }

}
