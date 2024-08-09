//
//  UserBackgroundImagesManager.swift
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

import CoreImage
import Foundation
import SwiftUI

struct UserBackgroundImage: Hashable, Identifiable, ColorSchemeProviding {
    let fileName: String
    let colorScheme: ColorScheme

    var id: String {
        fileName
    }
}

protocol UserBackgroundImagesManaging {
    var storageLocation: URL { get }
    var maximumNumberOfImages: Int { get }
    var availableImages: [UserBackgroundImage] { get }

    func addImage(with url: URL) async throws -> UserBackgroundImage?
    func image(for userBackgroundImage: UserBackgroundImage) -> NSImage?
}

protocol ImageColorSchemeCalculating {
    func calculatePreferredColorScheme(forImageAt url: URL) -> ColorScheme
}

extension ColorScheme: LosslessStringConvertible {
    public init?(_ description: String) {
        switch description {
        case "light":
            self = .light
        case "dark":
            self = .dark
        default:
            return nil
        }
    }

    public var description: String {
        self == .light ? "light" : "dark"
    }
}

extension UserBackgroundImage: LosslessStringConvertible {
    init?(_ description: String) {
        let components = description.split(separator: ";")
        guard components.count == 2, let colorScheme = ColorScheme(String(components[1])) else {
            return nil
        }
        self.fileName = String(components[0])
        self.colorScheme = colorScheme
    }

    var description: String {
        "\(fileName);\(colorScheme.description)"
    }
}

final class UserBackgroundImagesManager: UserBackgroundImagesManaging {

    let storageLocation: URL
    let maximumNumberOfImages: Int

    private(set) var availableImages: [UserBackgroundImage] = []

    @UserDefaultsWrapper(key: .homePageUserBackgroundImages, defaultValue: [])
    private var imagesMetadata: [String] {
        didSet {
            availableImages = imagesMetadata.compactMap(UserBackgroundImage.init)
        }
    }

    init(maximumNumberOfImages: Int, applicationSupportDirectory: URL) {
        assert(maximumNumberOfImages > 0, "maximumNumberOfImages must be greater than 0")
        self.maximumNumberOfImages = maximumNumberOfImages
        storageLocation = applicationSupportDirectory.appendingPathComponent("UserBackgroundImages")
        setUpStorageDirectory()
        availableImages = imagesMetadata.compactMap(UserBackgroundImage.init)
        verifyStoredImages()
    }

    func addImage(with url: URL) async throws -> UserBackgroundImage? {
        let fileName = [UUID().uuidString, url.pathExtension].joined(separator: ".")
        let destinationURL = storageLocation.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: url, to: destinationURL)

        let date = Date()
        let colorScheme = await Task {
            calculatePreferredColorScheme(forImageAt: destinationURL)
        }.value
        let diff = date.distance(to: Date())
        print("color scheme calculation took \(diff) seconds")

        let userBackgroundImage = UserBackgroundImage(fileName: fileName, colorScheme: colorScheme)

        if imagesMetadata.count > maximumNumberOfImages {
            let imagesToDelete = imagesMetadata.suffix(from: maximumNumberOfImages)
            imagesToDelete.forEach { imageMetadata in
                guard let fileName = UserBackgroundImage(imageMetadata)?.fileName else {
                    return
                }
                FileManager.default.remove(fileAtURL: storageLocation.appendingPathComponent(fileName))
            }
        }

        imagesMetadata = [userBackgroundImage.description] + imagesMetadata.prefix(maximumNumberOfImages - 1)
        return userBackgroundImage
    }

    func image(for userBackgroundImage: UserBackgroundImage) -> NSImage? {
        NSImage(contentsOf: storageLocation.appendingPathComponent(userBackgroundImage.fileName))
    }

    private func setUpStorageDirectory() {
        var isDirectory: ObjCBool = .init(booleanLiteral: false)
        let fileExists = FileManager.default.fileExists(atPath: storageLocation.path, isDirectory: &isDirectory)

        switch (fileExists, isDirectory.boolValue) {
        case (true, true):
            return
        case (true, false):
            assertionFailure("File at \(storageLocation.path) is not a directory")
        case (false, _):
            do {
                try FileManager.default.createDirectory(at: storageLocation, withIntermediateDirectories: true)
            } catch {
                // fire pixel
            }
        }
    }

    private func verifyStoredImages() {
        availableImages = availableImages.filter { image in
            let imagePath = storageLocation.appendingPathComponent(image.fileName).path
            return FileManager.default.fileExists(atPath: imagePath)
        }
    }
}

extension UserBackgroundImagesManager: ImageColorSchemeCalculating {

    func calculatePreferredColorScheme(forImageAt url: URL) -> ColorScheme {
        guard let image = NSImage(contentsOf: url), let averageBrightness = image.averageBrightness() else { return .light }
        return averageBrightness > 0.5 ? .light : .dark
    }

}

extension NSImage {
    func averageBrightness(sampleSize: Int = 2000) -> CGFloat? {
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
