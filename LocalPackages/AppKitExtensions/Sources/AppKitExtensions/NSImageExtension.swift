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
import CoreImage

extension NSImage {

    /**
     * This function samples image pixels to guess the average brightness.
     *
     * Up to `sampleSize` pixels (or all image pixels, whichever is smaller)
     * are analyzed for luminance and the average luminance is returned.
     */
    public func averageBrightness(sampleSize: Int = 2048) -> CGFloat? {
        guard let tiffData = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pixelData = bitmapImage.bitmapData else { return nil }

        let width = bitmapImage.pixelsWide
        let height = bitmapImage.pixelsHigh

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
            let r = CGFloat(pixelData[pixelIndex]) / 255.0
            let g = CGFloat(pixelData[pixelIndex + 1]) / 255.0
            let b = CGFloat(pixelData[pixelIndex + 2]) / 255.0

            let brightness = 0.2126 * r + 0.7152 * g + 0.0722 * b
            totalBrightness += brightness
            sampledPixels += 1
        }

        let averageBrightness = totalBrightness / CGFloat(sampledPixels)
        return averageBrightness
    }

    public func averageBrightnessBenchmark() -> CGFloat? {
        let brightness = calculateBrightness(downsample: true, invertGammaCorrection: false)

        print(String(format: "physical all pixels average:  %.5f", calculateBrightness() ?? 0))
        print(String(format: "physical 2048 pixels average: %.5f", calculateBrightness(sampleSize: 2048) ?? 0))
        print(String(format: "physical downsampled:         %.5f", calculateBrightness(downsample: true) ?? 0))
        print(String(format: "sRGB all pixels average:      %.5f", calculateBrightness(invertGammaCorrection: false) ?? 0))
        print(String(format: "sRGB 2048 pixels average:     %.5f", calculateBrightness(sampleSize: 2048, invertGammaCorrection: false) ?? 0))
        print(String(format: "sRGB downsampled:             %.5f", brightness ?? 0))

        return brightness
    }

    private func calculateBrightness(
        downsample: Bool = false,
        sampleSize: Int = 0,
        invertGammaCorrection: Bool = true
    ) -> CGFloat? {
        let image = downsample ? downsampledTo1x1PixelUsingCoreImage() : self

        guard let tiffData = image?.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pixelData = bitmapImage.bitmapData else { return nil }

        let width = bitmapImage.pixelsWide
        let height = bitmapImage.pixelsHigh

        let totalPixels = width * height
        let step = sampleSize == 0 ? 1 : max(1, totalPixels / sampleSize)

        var totalBrightness: CGFloat = 0.0
        var sampledPixels = 0

        for i in stride(from: 0, to: totalPixels, by: step) {
            let x = (i % width)
            let y = (i / width)
            let pixelIndex = (y * width + x) * 4

            // Consult https://www.w3.org/WAI/GL/wiki/Relative_luminance for more information
            // about gamma correction and relative luminance formula.
            var r = CGFloat(pixelData[pixelIndex]) / 255.0
            var g = CGFloat(pixelData[pixelIndex + 1]) / 255.0
            var b = CGFloat(pixelData[pixelIndex + 2]) / 255.0

            if invertGammaCorrection {
                r = invertingGammaCorrection(CGFloat(pixelData[pixelIndex]) / 255.0)
                g = invertingGammaCorrection(CGFloat(pixelData[pixelIndex + 1]) / 255.0)
                b = invertingGammaCorrection(CGFloat(pixelData[pixelIndex + 2]) / 255.0)
            }

            let brightness = 0.2126 * r + 0.7152 * g + 0.0722 * b
            totalBrightness += brightness
            sampledPixels += 1
        }

        let averageBrightness = totalBrightness / CGFloat(sampledPixels)
        return averageBrightness
    }

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

    private func downsampledTo1x1PixelUsingCoreImage() -> NSImage? {
        // Ensure the image has a valid representation
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let ciImage = CIImage(bitmapImageRep: bitmapImage) else {
            return nil
        }

        // Create a Core Image context
        let context = CIContext(options: nil)

        // Apply the Lanczos scale transform filter
        let scaleFilter = CIFilter(name: "CILanczosScaleTransform")
        scaleFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        scaleFilter?.setValue(1.0 / ciImage.extent.size.width, forKey: kCIInputScaleKey)
        scaleFilter?.setValue(1.0, forKey: kCIInputAspectRatioKey)

        // Get the output image
        guard let outputCIImage = scaleFilter?.outputImage else {
            return nil
        }

        // Crop the image to 1x1 pixel
        let croppedCIImage = outputCIImage.cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))

        // Render the CIImage to a CGImage
        guard let cgImage = context.createCGImage(croppedCIImage, from: croppedCIImage.extent) else {
            return nil
        }

        // Convert the CGImage to NSImage
        let downsampledImage = NSImage(cgImage: cgImage, size: NSSize(width: 1, height: 1))

        return downsampledImage
    }

    private func invertingGammaCorrection(_ colorComponent: CGFloat) -> CGFloat {
        return pow(colorComponent, 2.2)
    }
}
