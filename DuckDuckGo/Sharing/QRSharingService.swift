//
//  QRSharingService.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Foundation
import QuickLookUI

final class QRSharingService: NSSharingService {

    private enum Constants {
        static let menuIcon = NSImage(named: "QR-Icon")!
    }

    private var qrImage: NSImage?
    private var imageUrl: URL?

    private var cancellables = Set<AnyCancellable>()

    init() {
        super.init(title: UserText.shareViaQRCodeMenuItem, image: Constants.menuIcon, alternateImage: nil) {}
    }

    /// Get ASCII `Data` for an array of items to share that can be represented as strings (e.g., URLs or Strings).
    private static func data(for items: [Any]?) -> Data? {
        guard let items else { return nil }

        for item in items {
            var string: String? {
                switch item {
                case let url as URL:
                    return url.absoluteString
                case let string as String:
                    return string
                default:
                    return nil
                }
            }
            if let data = string?.data(using: .nonLossyASCII) {
                return data
            }
        }

        return nil
    }

    override func canPerform(withItems items: [Any]?) -> Bool {
        Self.data(for: items) != nil
    }

    private static func qrCode(for items: [Any]) -> CIImage? {
        guard let data = Self.data(for: items)  else { return nil }
        let isDuckDuckGoURL = items.contains(where: { ($0 as? URL)?.isDuckDuckGo ?? false })

        return CIImage.qrCode(for: data, parameters: isDuckDuckGoURL ? .duckDuckGo : .default)
    }

    override func perform(withItems items: [Any]) {
        guard let qr = Self.qrCode(for: items) else { return }

        let cgImage = qr.cgImage
        guard let data = cgImage.bitmapRepresentation(using: .png) else { return }

        // save to temp directory, will be removed on QLPreviewPanel hide
        let fileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        do {
            try data.write(to: fileUrl)
        } catch {
            return
        }

        self.imageUrl = fileUrl
        self.qrImage = NSImage(cgImage: cgImage, size: NSSize(width: qr.extent.size.width / 2, height: qr.extent.size.height / 2))

        self.showQuickLook()
    }

    private func showQuickLook() {
        self.cancellables.removeAll()

        let qlPanel: QLPreviewPanel = QLPreviewPanel.shared()
        qlPanel.dataSource = self
        qlPanel.delegate = self

        if qlPanel.isVisible {
            qlPanel.reloadData()
        } else {
            qlPanel.makeKeyAndOrderFront(nil)
        }

        qlPanel.publisher(for: \.delegate).dropFirst().sink { [weak self] delegate in
            if delegate !== self {
                self?.cleanup()
            }
        }.store(in: &cancellables)

        qlPanel.publisher(for: \.isVisible).dropFirst().sink { [weak self] isVisible in
            if !isVisible {
                self?.cleanup()
            }
        }.store(in: &cancellables)
    }

    private func cleanup() {
        guard let imageUrl else { return }

        if let qlPanel = QLPreviewPanel.shared(),
           qlPanel.delegate === self,
           qlPanel.isVisible {
            qlPanel.orderOut(nil)
        }

        try? FileManager.default.removeItem(at: imageUrl)
        self.imageUrl = nil
        self.qrImage = nil
        self.cancellables.removeAll()
    }

}

extension QRSharingService: QLPreviewPanelDataSource, QLPreviewPanelDelegate {

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return imageUrl != nil ? 1 : 0
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return imageUrl as QLPreviewItem?
    }

    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        return qrImage.map { NSRect(origin: .zero, size: $0.size) } ?? .zero
    }

    func previewPanel(_ panel: QLPreviewPanel!, transitionImageFor item: QLPreviewItem!, contentRect: UnsafeMutablePointer<NSRect>!) -> Any! {
        return qrImage
    }

}
