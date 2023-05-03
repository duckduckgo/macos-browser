//
//  QRSharingServive.swift
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

        static let logo = NSImage(named: "Logo")!
        static let logoRadiusFactor: CGFloat = 0.8
        static let logoMargin: CGFloat = 8
        static let logoBackgroundColor = NSColor.white
        static let logoSizeFactor: CGFloat = 0.25

        static let qrSize: Int = 500
        static let qrCorrectionLevel: CIImage.QRCorrectionLevel? = .high

        static let backgroundColor = NSColor.white
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

    private static func qrCode(for items: [Any]) -> CIImage? {
        guard let data = Self.data(for: items),
              var qr = CIImage.qrCode(for: data, correctionLevel: Constants.qrCorrectionLevel) else { return nil }

        // size of a QR “dot”
        let qrSize = qr.extent.size.width

        // scale
        let qrScale = CGFloat(CGFloat(Constants.qrSize) / CGFloat(qrSize))
        qr = qr.scaled(by: qrScale)

        // tint
        qr = qr.tinted(using: .logoBackgroundColor)

        // extend background by 2 QR dots in each dimension
        let backgroundExtent = qr.extent.insetBy(dx: -2 * qrScale, dy: -2 * qrScale)
        let background = CIImage.rect(in: backgroundExtent, cornerRadius: qrScale * 2, color: Constants.backgroundColor)
        // add background
        qr = qr.centered(in: backgroundExtent).composited(over: background)

        // add logo
        var logo: CIImage {
            var image = Constants.logo.ciImage

            // cut Dax circle
            let maskImage = CIImage.circle(at: image.extent.center, radius: image.extent.width * (Constants.logoRadiusFactor / 2))
            image = image.masked(with: maskImage)

            // add background
            let backgroundExtent = CGRect(x: 0, y: 0, width: image.extent.width + Constants.logoMargin * 2, height: image.extent.width + Constants.logoMargin * 2)
            let background = CIImage.rect(in: backgroundExtent, cornerRadius: backgroundExtent.width / 2, color: Constants.logoBackgroundColor)
            image = image.centered(in: backgroundExtent).composited(over: background)

            // scale to logoSizeInQRDots to match exact number of dots
            let sizeInDots = CGFloat(Int(qrSize * Constants.logoSizeFactor))

            image = image.scaled(by: (qrScale * sizeInDots) / image.extent.width)

            return image
        }
        qr = logo.centered(in: qr.extent).composited(over: qr)

        return qr
    }

    override func canPerform(withItems items: [Any]?) -> Bool {
        Self.data(for: items) != nil
    }

    override func perform(withItems items: [Any]) {
        guard let qr = Self.qrCode(for: items) else { return }

        let cgImage = qr.cgImage
        guard let data = cgImage.bitmapRepresentation(using: .png) else { return }

        let fileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        do {
            try data.write(to: fileUrl)
        } catch {
            return
        }

        self.imageUrl = fileUrl
        self.qrImage = NSImage(cgImage: cgImage, size: NSSize(width: qr.extent.size.width / 2, height: qr.extent.size.height / 2))

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
