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
            let r = CGFloat(pixelData[pixelIndex]) / 255.0
            let g = CGFloat(pixelData[pixelIndex + 1]) / 255.0
            let b = CGFloat(pixelData[pixelIndex + 2]) / 255.0

            // Calculate brightness using the luminance formula
            let brightness = 0.299 * r + 0.587 * g + 0.114 * b
            totalBrightness += brightness
            sampledPixels += 1
        }

        let averageBrightness = totalBrightness / CGFloat(sampledPixels)
        return averageBrightness
    }
}
