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

    /**
     * This function calculates the average brightness using relative luminancy formula.
     *
     * The image is downsampled to 1 pixel and that pixel's luminance is calculated.
     */
    public func averageBrightness() -> CGFloat? {
        guard let tiffData = downsampledTo1x1Pixel().tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pixelData = bitmapImage.bitmapData else { return nil }

        let pixel = pixelData.withMemoryRebound(to: UInt8.self, capacity: 1) { pointer in
            pointer.pointee
        }

        let pixelValue = CGFloat(pixel) / 255.0

        // Consult https://www.w3.org/WAI/GL/wiki/Relative_luminance for more information
        // about gamma correction and relative luminance formula.
        let r = invertingGammaCorrection(pixelValue)
        let g = invertingGammaCorrection(pixelValue)
        let b = invertingGammaCorrection(pixelValue)

        let brightness = 0.2126 * r + 0.7152 * g + 0.0722 * b

        return brightness
    }

//    /**
//     * This function samples image pixels to guess the average brightness.
//     *
//     * Up to `sampleSize` pixels (or all image pixels, whichever is smaller)
//     * are analyzed for luminance and the average luminance is returned.
//     */
//    public func averageBrightness(sampleSize: Int = 2048) -> CGFloat? {
//        guard let tiffData = self.tiffRepresentation,
//              let bitmapImage = NSBitmapImageRep(data: tiffData) else { return nil }
//
//        let date = Date()
//        let width = bitmapImage.pixelsWide
//        let height = bitmapImage.pixelsHigh
//
//        guard let pixelData = bitmapImage.bitmapData else { return nil }
//
//        let totalPixels = width * height
//        let step = max(1, totalPixels / sampleSize)
//
//        var totalBrightness: CGFloat = 0.0
//        var sampledPixels = 0
//
//        for i in stride(from: 0, to: totalPixels, by: step) {
//            let x = (i % width)
//            let y = (i / width)
//            let pixelIndex = (y * width + x) * 4
//
//            // Consult https://www.w3.org/WAI/GL/wiki/Relative_luminance for more information
//            // about gamma correction and relative luminance formula.
//            let r = invertingGammaCorrection(CGFloat(pixelData[pixelIndex]) / 255.0)
//            let g = invertingGammaCorrection(CGFloat(pixelData[pixelIndex + 1]) / 255.0)
//            let b = invertingGammaCorrection(CGFloat(pixelData[pixelIndex + 2]) / 255.0)
//
//            let brightness = 0.2126 * r + 0.7152 * g + 0.0722 * b
//            totalBrightness += brightness
//            sampledPixels += 1
//        }
//
//        let averageBrightness = totalBrightness / CGFloat(sampledPixels)
//        print("\(#function) took \(Date().timeIntervalSince(date)) seconds")
//        return averageBrightness
//    }

    private func downsampledTo1x1Pixel() -> NSImage {
        let newSize = NSSize(width: 1, height: 1)
        let newImage = NSImage(size: newSize)

        // Lock focus on the new image to draw into it
        newImage.lockFocus()

        // Set the interpolation quality to high for better downsampling
        NSGraphicsContext.current?.imageInterpolation = .high

        // Draw the original image into the new image context
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)

        newImage.unlockFocus()

        return newImage
    }

    private func invertingGammaCorrection(_ colorComponent: CGFloat) -> CGFloat {
        if colorComponent <= 0.03928 {
            return colorComponent / 12.92
        }
        return pow((colorComponent + 0.055)/1.055, 2.4)
    }
}
