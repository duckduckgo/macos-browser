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
import SwiftUI
import WebKit

final class TabSnapshotExtension {

    struct SnapshotData {
        var url: URL?
        var image: NSImage
        var webviewBoundsSize: NSSize
        var isRestored: Bool

        static func snapshotDataForNativeView(from image: NSImage) -> SnapshotData {
            return SnapshotData(url: nil, image: image, webviewBoundsSize: NSSize.zero, isRestored: false)
        }
    }

    private var identifier: UUID?

    private var snapshotData: SnapshotData? {
        didSet {
            if let snapshotData, let identifier {
                tabSnapshotPersistanceService.persistSnapshot(snapshotData.image,
                                                             id: identifier)
            }
        }
    }
    private var generateSnapshotAfterLoad = false
    private var userDidScroll = false

    var snapshot: NSImage? {
        return snapshotData?.image
    }

    private var cancellables = Set<AnyCancellable>()
    private weak var webView: WebView?
    private var tabContent: Tab.TabContent?

    private let tabSnapshotPersistanceService: TabSnapshotPersistenceService

    init(fileStore: FileStore = NSApplication.shared.delegateTyped.fileStore,
         webViewPublisher: some Publisher<WKWebView, Never>,
         contentPublisher: some Publisher<Tab.TabContent, Never>) {

        tabSnapshotPersistanceService = TabSnapshotPersistenceService(fileStore: fileStore)

        webViewPublisher.sink { [weak self] webView in
            self?.webView = webView as? WebView
            self?.webView?.scrollEventDelegate = self
        }.store(in: &cancellables)

        contentPublisher.sink { [weak self] tabContent in
            self?.tabContent = tabContent
        }.store(in: &cancellables)

        generateSnapshotAfterLoad = true
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
        if let snapshotData,
           !userDidScroll,
           snapshotData.webviewBoundsSize == webView.bounds.size,
           snapshotData.url == url {
            os_log("Skipping snapshot rendering, it is already generated. url: \(url)", log: .tabSnapshots)
            return
        }

        os_log("Preview rendering started", log: .tabSnapshots)
        let configuration = WKSnapshotConfiguration.makeConfiguration()

        webView.takeSnapshot(with: configuration) { [weak self] image, _ in
            guard let image = image else {
                os_log("Failed to create a snapshot of webView", log: .tabSnapshots, type: .error)
                return
            }
            self?.generateSnapshotAfterLoad = false
            self?.snapshotData = SnapshotData(url: url,
                                            image: image,
                                            webviewBoundsSize: webView.bounds.size,
                                            isRestored: false)

            os_log("Preview rendered: \(url) ", log: .tabSnapshots)
        }
    }

    @MainActor
    private func clearPreview() {
        snapshotData = nil
    }

    // MARK: - Native Previews

    func generateNativePreview(from view: NSView) {
        let originalBounds = view.bounds

        os_log("Native snapshot rendering started", log: .tabSnapshots)
        DispatchQueue.global(qos: .userInitiated).async {
            guard let resizedImage = self.createResizedImage(from: view, with: originalBounds) else {
                DispatchQueue.main.async { [weak self] in
                    os_log("Native snapshot rendering failed", log: .tabSnapshots, type: .error)
                    self?.clearPreview()
                }
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.snapshotData = SnapshotData.snapshotDataForNativeView(from: resizedImage)
                os_log("Preview of native page rendered", log: .tabSnapshots)
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

extension TabSnapshotExtension: WebViewScrollEventDelegate {

    func webView(_ webView: WebView, didScrollWheel event: NSEvent) {
        userDidScroll = true
    }

    func webView(_ webView: WebView, didScrollKey event: NSEvent) {
        userDidScroll = true
    }

}

extension TabSnapshotExtension: NSCodingExtension {

    private enum NSSecureCodingKeys {
        static let tabSnapshotIdentifier = "TabSnapshotIdentifier"
    }

    func awakeAfter(using decoder: NSCoder) {
        guard let uuidString = decoder.decodeObject(of: NSString.self, forKey: NSSecureCodingKeys.tabSnapshotIdentifier),
              let identifier = UUID(uuidString: uuidString as String) else {
            os_log("Snapshot id restoration failed", log: .tabSnapshots)
            self.identifier = UUID()
            return
        }

        self.identifier = identifier

        tabSnapshotPersistanceService.loadSnapshot(for: identifier) { [weak self] image in
            guard let image else {
                os_log("No snapshot restored", log: .tabSnapshots)
                return
            }
            self?.snapshotData = SnapshotData(url: nil,
                                            image: image,
                                            webviewBoundsSize: NSSize.zero,
                                            isRestored: true)
            os_log("Snapshot restored", log: .tabSnapshots)

            self?.generateSnapshotAfterLoad = false
        }
    }

    func encode(using coder: NSCoder) {
        if let identifier {
            coder.encode(identifier.uuidString,
                         forKey: NSSecureCodingKeys.tabSnapshotIdentifier)
            os_log("Snapshot id saved to the session state", log: .tabSnapshots)
        }
    }

}

extension TabSnapshotExtension: NavigationResponder {

    @MainActor
    func willStart(_ navigation: Navigation) {
        if snapshotData?.isRestored == false {
            clearPreview()
        }

        userDidScroll = false
    }

    @MainActor
    func didFinishLoad(with request: URLRequest, in frame: WKFrameInfo) {
        if generateSnapshotAfterLoad {
            Task {
                await generatePreview()
            }
        }
    }

}

protocol TabPreviewExtensionProtocol: AnyObject, NavigationResponder {

    var snapshot: NSImage? { get }

    func generatePreview() async
    func generateNativePreview(from view: NSView)

}

extension TabSnapshotExtension: TabPreviewExtensionProtocol, TabExtension {
    func getPublicProtocol() -> TabPreviewExtensionProtocol { self }
}

extension TabExtensions {
    var tabPreviews: TabPreviewExtensionProtocol? { resolve(TabSnapshotExtension.self) }
}

extension Tab {

    var tabSnapshot: NSImage? {
        return self.tabPreviews?.snapshot
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
