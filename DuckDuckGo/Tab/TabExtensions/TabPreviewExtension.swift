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
import WebKit

final class TabPreviewExtension {

    struct PreviewData {
        var url: URL?
        var image: NSImage
        var webviewBoundsSize: NSSize
        var isRestored: Bool

        static func previewDataForNativeView(from image: NSImage) -> PreviewData {
            return PreviewData(url: nil, image: image, webviewBoundsSize: NSSize.zero, isRestored: false)
        }
    }

    private var previewData: PreviewData?
    private var generatePreviewAfterLoad = false
    private var userDidScroll = false

    var preview: NSImage? {
        return previewData?.image
    }

    private var cancellables = Set<AnyCancellable>()
    private weak var webView: WebView?
    private var tabContent: Tab.TabContent?

    init(webViewPublisher: some Publisher<WKWebView, Never>, contentPublisher: some Publisher<Tab.TabContent, Never>) {
        webViewPublisher.sink { [weak self] webView in
            self?.webView = webView as? WebView
            self?.webView?.scrollEventDelegate = self
        }.store(in: &cancellables)

        contentPublisher.sink { [weak self] tabContent in
            self?.tabContent = tabContent
        }.store(in: &cancellables)

        generatePreviewAfterLoad = true
    }

    // MARK: - Webviews

    @MainActor
    func generatePreview() async {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let webView, let tabContent, let url = tabContent.url else {
            // Previews of native views are generated in generateNativePreview()
            return
        }

        // Avoid unnecessary generations
        if let previewData,
           !userDidScroll,
           previewData.webviewBoundsSize == webView.bounds.size,
           previewData.url == url {
            os_log("Skipping preview rendering, it is already generated. url: \(url)", log: .tabPreviews)
            return
        }

        os_log("Preview rendering started", log: .tabPreviews)
        let configuration = WKSnapshotConfiguration.makeConfiguration()

        webView.takeSnapshot(with: configuration) { [weak self] image, _ in
            guard let image = image else {
                os_log("Failed to create a snapshot of webView", log: .tabPreviews, type: .error)
                return
            }
            self?.generatePreviewAfterLoad = false
            self?.previewData = PreviewData(url: url,
                                            image: image,
                                            webviewBoundsSize: webView.bounds.size,
                                            isRestored: false)

            os_log("Preview rendered: \(url) ", log: .tabPreviews)
        }
    }

    @MainActor
    private func clearPreview() {
        previewData = nil
    }

    // MARK: - Native Previews

    func generateNativePreview(from view: NSView) {
        let originalBounds = view.bounds

        os_log("Native preview rendering started", log: .tabPreviews)
        DispatchQueue.global(qos: .userInitiated).async {
            guard let resizedImage = self.createResizedImage(from: view, with: originalBounds) else {
                DispatchQueue.main.async { [weak self] in
                    os_log("Native preview rendering failed", log: .tabPreviews, type: .error)
                    self?.clearPreview()
                }
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.previewData = PreviewData.previewDataForNativeView(from: resizedImage)
                os_log("Preview of native page rendered", log: .tabPreviews)
            }
        }
    }

    private func createResizedImage(from view: NSView, with bounds: CGRect) -> NSImage? {
        let originalSize = bounds.size
        let targetWidth = CGFloat(TabPreviewWindowController.Size.width.rawValue)
        let targetHeight = originalSize.height * (targetWidth / originalSize.width)

        guard let bitmapRep = createBitmapRepresentation(size: originalSize) else { return nil }
        renderView(view, to: bitmapRep, size: originalSize)

        let originalImage = NSImage(size: originalSize)
        originalImage.addRepresentation(bitmapRep)

        return resizeImage(originalImage, to: NSSize(width: targetWidth, height: targetHeight))
    }

    private func createBitmapRepresentation(size: CGSize) -> NSBitmapImageRep? {
        NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSColorSpaceName.deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0)
    }

    private func renderView(_ view: NSView, to bitmapRep: NSBitmapImageRep, size: CGSize) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        if let context = NSGraphicsContext(bitmapImageRep: bitmapRep) {
            NSGraphicsContext.current = context
            DispatchQueue.main.sync {
                assert(Thread.isMainThread)
                context.cgContext.translateBy(x: 0, y: size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                view.layer?.render(in: context.cgContext)
            }
        }
    }

    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()
        defer { resizedImage.unlockFocus() }
        image.draw(in: NSRect(x: 0, y: 0, width: size.width, height: size.height), from: NSRect.zero, operation: .copy, fraction: 1.0)
        return resizedImage
    }

}

extension TabPreviewExtension: WebViewScrollEventDelegate {

    func webView(_ webView: WebView, didScrollWheel event: NSEvent) {
        userDidScroll = true
    }

    func webView(_ webView: WebView, didScrollKey event: NSEvent) {
        userDidScroll = true
    }

}

extension TabPreviewExtension: NSCodingExtension {

    private enum NSSecureCodingKeys {
        static let tabPreviewImage = "TabPreviewImage"
    }

    func awakeAfter(using decoder: NSCoder) {
        guard let data = decoder.decodeObject(of: NSData.self, forKey: NSSecureCodingKeys.tabPreviewImage),
              let image = NSImage(data: data as Data) else {
            os_log("Preview restoration failed", log: .tabPreviews)
            return
        }

        previewData = PreviewData(url: nil, image: image, webviewBoundsSize: NSSize.zero, isRestored: true)
        os_log("Preview restored from the session state", log: .tabPreviews)
        generatePreviewAfterLoad = false
    }

    func encode(using coder: NSCoder) {
        if let previewData {
            os_log("Preview saved to the session state", log: .tabPreviews)
            coder.encode(previewData.image.tiffRepresentation, forKey: NSSecureCodingKeys.tabPreviewImage)
        }
    }

}

extension TabPreviewExtension: NavigationResponder {

    @MainActor
    func willStart(_ navigation: Navigation) {
        if previewData?.isRestored == false {
            clearPreview()
        }

        userDidScroll = false
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
