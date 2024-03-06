//
//  CIImageExtension.swift
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

import AppKit
import CoreImage.CIFilterBuiltins

extension CIImage {

    static var retinaScaleFactor: CGFloat {
        max(NSScreen.maxBackingScaleFactor, NSScreen.defaultBackingScaleFactor) // “retina” or larger
    }

    /// Generates a `CIImage` of a rounded rectangle with a specified extent and corner radius.
    static func rect(in extent: CGRect, cornerRadius: CGFloat = 0, color: NSColor? = nil) -> CIImage {
        let roundedRectFilter = CIFilter.roundedRectangleGenerator()
        roundedRectFilter.extent = extent
        roundedRectFilter.radius = Float(cornerRadius)
        if let color {
            roundedRectFilter.color = color.ciColor
        }

        return roundedRectFilter.outputImage!
    }

    /// Generates a `CIImage` of a circle with a specified center point and radius.
    static func circle(at center: CGPoint, radius: CGFloat, color: NSColor? = nil) -> CIImage {
        return rect(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), cornerRadius: radius, color: color)
    }

    enum QRCorrectionLevel: String {
        /// 7% of codewords can be restored.
        case low = "L"
        /// 15% of codewords can be restored.
        case medium = "M"
        /// 25% of codewords can be restored.
        case normal = "Q"
        /// 30% of codewords can be restored.
        case high = "H"
    }
    /// Generates a QR code `CIImage` for a given data input.
    static func qrCode(for data: Data, correctionLevel: QRCorrectionLevel? = nil) -> CIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        if let correctionLevel {
            filter.correctionLevel = correctionLevel.rawValue
        }
        return filter.outputImage
    }

    struct QRCodeParameters {

        fileprivate static let iconSizeFactor: CGFloat = 0.25

        var logicalQrSize: Int
        var correctionLevel: QRCorrectionLevel?

        var icon: CIImage?

        var color: NSColor
        var backgroundColor: NSColor

        static let `default` = QRCodeParameters(logicalQrSize: 250,
                                                correctionLevel: nil,
                                                icon: nil,
                                                color: .black,
                                                backgroundColor: .white)

        static let duckDuckGo: QRCodeParameters = {
            let logicalQrSize = QRCodeParameters.default.logicalQrSize
            let icon: CIImage = {
                let logo = NSImage.logo
                let logoRadiusFactor: CGFloat = 0.77
                let logoMargin: CGFloat = 6
                let logoBackgroundColor: NSColor = .logoBackground

                let logoSize = NSSize(width: logicalQrSize, height: logicalQrSize).scaled(by: CIImage.retinaScaleFactor)
                var image = logo.ciImage(with: logoSize)

                // cut Dax circle
                let maskImage = CIImage.circle(at: image.extent.center, radius: image.extent.width * (logoRadiusFactor / 2))
                image = image.masked(with: maskImage)

                // add background
                let backgroundExtent = CGRect(x: 0, y: 0, width: image.extent.width + logoMargin * 2, height: image.extent.width + logoMargin * 2)
                let background = CIImage.rect(in: backgroundExtent, cornerRadius: backgroundExtent.width / 2, color: logoBackgroundColor)
                image = image.centered(in: backgroundExtent).composited(over: background)

                return image
            }()

            return QRCodeParameters(logicalQrSize: logicalQrSize,
                                    correctionLevel: .high,
                                    icon: icon,
                                    color: .logoBackground,
                                    backgroundColor: .white)
        }()
    }

    static func qrCode(for data: Data, parameters: QRCodeParameters = .default) -> CIImage? {
        guard var qr = CIImage.qrCode(for: data, correctionLevel: parameters.correctionLevel) else { return nil }

        // size of the QR in “dots”
        let qrSize = qr.extent.size.width

        // scale to QR Size in Pixels
        let qrScale = CGFloat((CGFloat(parameters.logicalQrSize) * CIImage.retinaScaleFactor) / CGFloat(qrSize))
        qr = qr.scaled(by: qrScale)

        // tint
        qr = qr.tinted(using: parameters.color)

        // extend background by 2 QR dots in each dimension
        let backgroundExtent = qr.extent.insetBy(dx: -2 * qrScale, dy: -2 * qrScale)
        let background = CIImage.rect(in: backgroundExtent, cornerRadius: qrScale * 2, color: parameters.backgroundColor)
        // add background
        qr = qr.centered(in: backgroundExtent).composited(over: background)

        // add logo
        if let icon = parameters.icon {
            let sizeInDots = CGFloat(Int(qrSize * QRCodeParameters.iconSizeFactor))
            let icon = icon.scaled(by: (qrScale * sizeInDots) / icon.extent.width)

            qr = icon.centered(in: qr.extent).composited(over: qr)
        }

        return qr
    }

    /// Creates a new `CIImage` by masking the current image with the specified mask image.
    func masked(with maskImage: CIImage) -> CIImage {
        let filter = CIFilter.blendWithMask()
        filter.inputImage = self
        filter.maskImage = maskImage

        return filter.outputImage!.cropped(to: maskImage.extent)
    }

    /// Generates a new `CIImage` by scaling the input image by a specified scale factor.
    func scaled(by scaleFactor: CGFloat) -> CIImage {
        let transform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        return self.transformed(by: transform)
    }

    /// Returns a new `CIImage` by centering the current image within another image's extent.
    func centered(in otherExtent: CGRect) -> CIImage {
        self.transformed(by: CGAffineTransform(translationX: otherExtent.midX - extent.midX, y: otherExtent.midY - extent.midY))
    }

    /// Generates a new `CIImage` by inverting the colors of the input image.
    func inverted() -> CIImage! {
        let invertedColorFilter = CIFilter.colorInvert()
        invertedColorFilter.inputImage = self

        return invertedColorFilter.outputImage
    }

    /// Generates a new `CIImage` by converting black areas of the input image to transparent and other areas to white.
    func blackToTransparent() -> CIImage! {
        let blackTransparentFilter = CIFilter.maskToAlpha()
        blackTransparentFilter.inputImage = self

        return blackTransparentFilter.outputImage
    }

    /// Generates a new `CIImage` by tinting the input image with a specified color using multiply compositing.
    func tinted(using color: NSColor) -> CIImage! {
        let filter = CIFilter.multiplyCompositing()
        filter.inputImage = CIImage(color: color.ciColor)
        filter.backgroundImage = self.inverted()?.blackToTransparent()

        return filter.outputImage
    }

    var cgImage: CGImage {
        CIContext(options: nil).createCGImage(self, from: self.extent)!
    }

}

extension CGImage {

    /// Returns image bitmap data with the specified file format.
    func bitmapRepresentation(using format: NSBitmapImageRep.FileType) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: self)
        bitmapRep.size = NSSize(width: Int(CGFloat(self.width) / CIImage.retinaScaleFactor),
                                height: Int(CGFloat(self.height) / CIImage.retinaScaleFactor))

        return bitmapRep.representation(using: format, properties: [:])
    }

}
