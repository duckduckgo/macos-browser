//
//  AverageBrightnessTests.swift
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
//

@testable import AppKitExtensions
import XCTest

final class AverageBrightnessTests: XCTestCase {

    func testThatBrightnessCalculatedAfterDownsamplingIsSimilarToAllPixelsAverage() throws {

        for fileName in ["sample1.jpg", "sample2.jpg", "sample3.jpg", "sample4.png", "sample5.png"] {
            let components = fileName.components(separatedBy: ".")
            let imageURL = try XCTUnwrap(Bundle.module.url(forResource: components[0], withExtension: components[1]))
            let image = try XCTUnwrap(NSImage(contentsOf: imageURL))

            let allPixelsBrightness = try XCTUnwrap(image.calculateBrightness())
            let downsampledBrightness = try XCTUnwrap(image.calculateBrightness(downsample: true))

            XCTAssertEqual(allPixelsBrightness, downsampledBrightness, accuracy: 0.01)
        }

    }
}

extension NSImage {

    func calculateBrightness(downsample: Bool = false) -> CGFloat? {
        let image = downsample ? downsampledTo1x1Pixel() : self

        guard let tiffData = image?.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pixelData = bitmapImage.bitmapData else { return nil }

        let width = bitmapImage.pixelsWide
        let height = bitmapImage.pixelsHigh
        let totalPixels = width * height
        var totalBrightness: CGFloat = 0.0

        for i in 0..<totalPixels {
            let x = (i % width)
            let y = (i / width)

            let brightness = brightnessForPixel(x: x, y: y, in: pixelData, pixelsWide: bitmapImage.pixelsWide)
            totalBrightness += brightness
        }

        let averageBrightness = totalBrightness / CGFloat(totalPixels)
        return averageBrightness
    }
}
