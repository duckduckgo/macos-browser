//
//  QRCodeView.swift
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

import SwiftUI
import CoreImage

struct QRCode: View {
    let string: String
    let size: CGSize

    init(string: String, size: CGSize) {
        self.string = string
        self.size = size
    }

    var body: some View {
        Image(nsImage: generateQRCode(from: string, size: size))
            .frame(width: size.width, height: size.height)
    }

    func generateQRCode(from text: String, size: CGSize) -> NSImage {
        var qrImage: NSImage = {
            return NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil) ?? NSImage()
        }()
        let data = Data(text.utf8)
        let qrCodeFilter: CIFilter = CIFilter(name: "CIQRCodeGenerator")!
        qrCodeFilter.setValue(data, forKey: "inputMessage")
        qrCodeFilter.setValue("H", forKey: "inputCorrectionLevel")

        guard let naturalSize = qrCodeFilter.outputImage?.extent.width else {
            assertionFailure("Failed to generate qr code")
            return qrImage
        }

        let scale = size.width / naturalSize

        let transform = CGAffineTransform(scaleX: scale, y: scale)
        guard let outputImage = qrCodeFilter.outputImage?.transformed(by: transform) else {
            assertionFailure("transformation failed")
            return qrImage
        }

        let colorParameters: [String: Any] = [
            "inputColor0": CIColor(color: NSColor.black)!,
            "inputColor1": CIColor(color: NSColor.white)!
        ]
        let coloredImage = outputImage.applyingFilter("CIFalseColor", parameters: colorParameters)

        if let image = CIContext().createCGImage(coloredImage, from: outputImage.extent) {
            qrImage = NSImage(cgImage: image, size: size)
        }

        return qrImage
    }

}
