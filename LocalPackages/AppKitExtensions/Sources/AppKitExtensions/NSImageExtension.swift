//
//  NSImageExtension.swift
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

import AppKit

extension NSImage {

    public var pngData: Data? {
        guard let tiffRepresentation = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }

        return bitmapImage.representation(using: .png, properties: [:])
    }

    public var jpegData: Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmapImage.representation(using: .jpeg, properties: [:])
    }

    /**
     * This function calculates image brightness using relative luminance formula.
     *
     * The image is downsammpled to 1x1 pixel, and that pixel's luminance is computed.

     * > Related links:
     * [Tech Design](https://app.asana.com/0/481882893211075/1208090992610433/f)
     */
    public func averageBrightness() -> CGFloat? {
        guard let tiffData = downsampledTo1x1Pixel()?.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pixelData = bitmapImage.bitmapData else { return nil }

        return brightnessForPixel(x: 0, y: 0, in: pixelData, pixelsWide: bitmapImage.pixelsWide)
    }

    func brightnessForPixel(x: Int, y: Int, in pixelData: UnsafeMutablePointer<UInt8>, pixelsWide: Int) -> CGFloat {
        let pixelIndex = (y * pixelsWide + x) * 4

        //
        // Consult https://www.w3.org/WAI/GL/wiki/Relative_luminance for more information
        // about relative luminance formula and gamma correction.
        //
        // Consult https://almarklein.org/gamma.html for more information about
        // sRGB vs physical colors and to see why we're not applying inverse gamma correction
        // (because sRGB is linear to human perception, while physical color is linear
        // wrt the light intensity / number of photons).
        //
        let r = CGFloat(pixelData[pixelIndex]) / 255.0
        let g = CGFloat(pixelData[pixelIndex + 1]) / 255.0
        let b = CGFloat(pixelData[pixelIndex + 2]) / 255.0

        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    func downsampledTo1x1Pixel() -> NSImage? {
        let newSize = CGSize(width: 1, height: 1)

        guard let context = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high

        // Draw the original image into the context
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(origin: .zero, size: newSize))

        // Create a CGImage from the context
        guard let downsampledCGImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: downsampledCGImage, size: NSSize(width: 1, height: 1))
    }
}
