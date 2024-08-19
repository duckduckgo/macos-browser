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
     * This function samples image pixels to guess the average brightness.
     *
     * Up to `sampleSize` pixels (or all image pixels, whichever is smaller)
     * are analyzed for luminance and the average luminance is returned.
     */
    public func averageBrightness(sampleSize: Int = 2048) -> CGFloat? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else { return nil }

        let date = Date()
        let width = bitmapImage.pixelsWide
        let height = bitmapImage.pixelsHigh

        guard let pixelData = bitmapImage.bitmapData else { return nil }

        let totalPixels = width * height
        let step = max(1, totalPixels / sampleSize)

        var totalBrightness: CGFloat = 0.0
        var sampledPixels = 0

        for i in stride(from: 0, to: totalPixels, by: step) {
            let x = (i % width)
            let y = (i / width)
            let pixelIndex = (y * width + x) * 4

            // Consult https://www.w3.org/WAI/GL/wiki/Relative_luminance for more information
            // about gamma correction and relative luminance formula.
            let r = invertingGammaCorrection(CGFloat(pixelData[pixelIndex]) / 255.0)
            let g = invertingGammaCorrection(CGFloat(pixelData[pixelIndex + 1]) / 255.0)
            let b = invertingGammaCorrection(CGFloat(pixelData[pixelIndex + 2]) / 255.0)

            let brightness = 0.2126 * r + 0.7152 * g + 0.0722 * b
            totalBrightness += brightness
            sampledPixels += 1
        }

        let averageBrightness = totalBrightness / CGFloat(sampledPixels)
        print("\(#function) took \(Date().timeIntervalSince(date)) seconds")
        return averageBrightness
    }

    private func invertingGammaCorrection(_ colorComponent: CGFloat) -> CGFloat {
        if colorComponent <= 0.03928 {
            return colorComponent / 12.92
        }
        return pow((colorComponent + 0.055)/1.055, 2.4)
    }
}
