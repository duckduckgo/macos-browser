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
import SwiftUI

final class TabPreviewExtension {

    struct PreviewData {
        var url: URL
        var scrollPosition: CGFloat
        var image: NSImage
        var webviewBoundsSize: NSSize
        var afterLoadPreview: Bool
    }

    private var previewData: PreviewData?
    private var generatePreviewAfterLoad = false

    var preview: NSImage? {
        switch tabContent {
        case .homePage, .preferences, .bookmarks, .onboarding, .dataBrokerProtection:
            return nativePreview
        case .url:
            return previewData?.image
        default:
            return nil
        }
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

        generatePreviewAfterLoad = true
    }

    // MARK: - Webviews
    
    @MainActor
    func generatePreview() async {
        await generatePreview(afterLoad: false)
    }

    @MainActor
    func generatePreview(afterLoad: Bool = false) async {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let webView, let tabContent, let url = tabContent.url else {
            // Previews of native views are generated in generateNativePreview()
            return
        }

        // Avoid unnecessary generations
        let scrollPosition = try? await getScrollPosition(webView: webView)
        if let previewData,
           let scrollPosition,
           !previewData.afterLoadPreview,
           previewData.webviewBoundsSize == webView.bounds.size,
           previewData.url == url,
           previewData.scrollPosition == scrollPosition {
            os_log("Skipping preview rendering, it is already generated. url: \(url) scrollPosition \(scrollPosition)", log: .tabPreviews)
            return
        }

        let configuration = WKSnapshotConfiguration.makeConfiguration()
        webView.takeSnapshot(with: configuration) { [weak self] image, _ in
            guard let image = image else {
                os_log("TabPreviewExtension: failed to create a snapshot of webView", log: .tabPreviews, type: .error)
                return
            }
            self?.generatePreviewAfterLoad = false
            self?.previewData = PreviewData(url: url,
                                            scrollPosition: scrollPosition ?? -1,
                                            image: image,
                                            webviewBoundsSize: webView.bounds.size,
                                            afterLoadPreview: afterLoad)

            os_log("Preview rendered: \(url) ", log: .tabPreviews)
        }
    }

    @MainActor
    private func getScrollPosition(webView: WKWebView) async throws -> CGFloat? {
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

    // MARK: - Native views

    private var nativePreview: NSImage?

    func generateNativePreview(from view: NSView) {
        //TODO: Optimize

        let originalSize = view.bounds.size
        let targetWidth = CGFloat(TabPreviewWindowController.Size.width.rawValue)
        let targetHeight = originalSize.height * (targetWidth / originalSize.width) // Preserving aspect ratio

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(originalSize.width),
            pixelsHigh: Int(originalSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSColorSpaceName.deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0) else {
            return
        }

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.current = context

        if let cgContext = context?.cgContext {
            cgContext.translateBy(x: 0, y: originalSize.height)
            cgContext.scaleBy(x: 1.0, y: -1.0)
            view.layer?.render(in: cgContext)
        }

        NSGraphicsContext.restoreGraphicsState()

        let originalImage = NSImage(size: originalSize)
        originalImage.addRepresentation(bitmapRep)

        // Resize the image to the target width while preserving the aspect ratio
        let resizedImage = NSImage(size: NSSize(width: targetWidth, height: targetHeight))
        resizedImage.lockFocus()
        originalImage.draw(in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight), from: NSRect.zero, operation: .copy, fraction: 1.0)
        resizedImage.unlockFocus()
        nativePreview = resizedImage
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
        //TODO: native previews too
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
                await generatePreview(afterLoad: true)
            }
        }
    }

}

protocol TabPreviewExtensionProtocol: AnyObject, NavigationResponder {

    var preview: NSImage? { get }

    func generatePreview() async
    func generateNativePreview(from view: NSView)

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
        configuration.snapshotWidth = NSNumber(floatLiteral: TabPreviewWindowController.Size.width.rawValue)
        return configuration
    }

}
