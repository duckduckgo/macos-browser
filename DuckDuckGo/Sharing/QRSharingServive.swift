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

import CoreImage
import Foundation
import QuickLookUI

extension String {

    /// Creates a QR code for the current URL in the given color.
    func qrImage(using color: NSColor) -> CIImage? {
        return qrImage?.tinted(using: color)
    }

    /// Returns a black and white QR code for this URL.
    var qrImage: CIImage? {
        guard let qrFilter = CIFilter(name: "CIQRCodeGenerator"),
              let qrData = self.data(using: String.Encoding.ascii) else { return nil }

        qrFilter.setValue(qrData, forKey: "inputMessage")

        let qrTransform = CGAffineTransform(scaleX: 12, y: 12)
        return qrFilter.outputImage?.transformed(by: qrTransform)
    }

    /// Creates a QR code for the current URL in the given color.
    func qrImage(using color: NSColor, logo: NSImage? = nil) -> CIImage? {
        let tintedQRImage = qrImage?.tinted(using: color)

        guard let logo = logo?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return tintedQRImage
        }

        return tintedQRImage?.combined(with: CIImage(cgImage: logo))
    }

}

extension CIImage {
    /// Inverts the colors and creates a transparent image by converting the mask to alpha.
    /// Input image should be black and white.
    var transparent: CIImage? {
        return inverted?.blackTransparent
    }

    /// Inverts the colors.
    var inverted: CIImage? {
        guard let invertedColorFilter = CIFilter(name: "CIColorInvert") else { return nil }

        invertedColorFilter.setValue(self, forKey: "inputImage")
        return invertedColorFilter.outputImage
    }

    /// Converts all black to transparent.
    var blackTransparent: CIImage? {
        guard let blackTransparentFilter = CIFilter(name: "CIMaskToAlpha") else { return nil }
        blackTransparentFilter.setValue(self, forKey: "inputImage")
        return blackTransparentFilter.outputImage
    }

    /// Applies the given color as a tint color.
    func tinted(using color: NSColor) -> CIImage? {
        guard
            let transparentQRImage = transparent,
            let filter = CIFilter(name: "CIMultiplyCompositing"),
            let colorFilter = CIFilter(name: "CIConstantColorGenerator") else { return nil }

        let ciColor = CIColor(color: color)
        colorFilter.setValue(ciColor, forKey: kCIInputColorKey)
        let colorImage = colorFilter.outputImage

        filter.setValue(colorImage, forKey: kCIInputImageKey)
        filter.setValue(transparentQRImage, forKey: kCIInputBackgroundImageKey)

        return filter.outputImage!
    }

    /// Combines the current image with the given image centered.
    func combined(with image: CIImage) -> CIImage? {
        guard let combinedFilter = CIFilter(name: "CISourceOverCompositing") else { return nil }
        let centerTransform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            .concatenating(CGAffineTransform(translationX: extent.midX - (image.extent.size.width / 4), y: extent.midY - (image.extent.size.height / 4)))
        combinedFilter.setValue(image.transformed(by: centerTransform), forKey: "inputImage")
        combinedFilter.setValue(self, forKey: "inputBackgroundImage")
        return combinedFilter.outputImage!
    }
}

final class QRSharingService: NSSharingService, QLPreviewPanelDataSource, QLPreviewPanelDelegate {

    static let logo = NSImage(named: "Logo")!

    private var qrImage: NSImage?
    private var imageUrl: URL?

    init() {
        super.init(title: "QR Code", image: NSImage(named: "Burn")!, alternateImage: nil) {
            print("Share")
        }
    }

    override func canPerform(withItems items: [Any]?) -> Bool {
        items?.contains(where: { $0 is String || $0 is URL }) ?? false
    }

    override func perform(withItems items: [Any]) {
        guard let string = items.lazy.compactMap({ ($0 as? URL)?.absoluteString ?? ($0 as? String) }).first else { return }

        let context = CIContext(options: nil)

        guard let ciImage = string.qrImage(using: .logoBackground, logo: Self.logo),
              let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            fatalError("Failed to create CGImage from CIImage")
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        let nsImage = NSImage(size: bitmapRep.size)
        nsImage.addRepresentation(bitmapRep)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            try? FileManager.default.removeItem(at: url)
        }

        try? bitmapRep.representation(using: .png, properties: [:])?.write(to: url)
        self.imageUrl = url

        self.qrImage = nsImage

        QLPreviewPanel.shared().dataSource = self
        QLPreviewPanel.shared().delegate = self

        if QLPreviewPanel.shared().isVisible {
            QLPreviewPanel.shared().reloadData()
        } else {
            QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
        }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return 1 // Change this number according to the number of items you want to preview
    }

    // Item to preview
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return imageUrl! as QLPreviewItem
    }

    // Frame for the item's icon in your view
    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        // Provide the frame of the item's icon in your view (optional)
        return .init(origin: .zero, size: qrImage!.size)
    }

    // The view responsible for the item's icon
    func previewPanel(_ panel: QLPreviewPanel!, transitionImageFor item: QLPreviewItem!, contentRect: UnsafeMutablePointer<NSRect>!) -> Any! {
        // Provide the image of the item's icon (optional)
        return qrImage
    }

}
