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

struct UserBackgroundImage: Equatable, ColorSchemeProviding {
    let fileName: String
    let colorScheme: ColorScheme
}

protocol UserBackgroundImagesManaging {
    var storageLocation: URL { get }
    var maximumNumberOfImages: Int { get }
    var availableImages: [UserBackgroundImage] { get }

    func addImage(with url: URL) throws
    func image(for userBackgroundImage: UserBackgroundImage) -> NSImage?
}

protocol ImageColorSchemeCalculating {
    func calculatePreferredColorScheme(for image: NSImage) -> ColorScheme
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
    private var imagesMetadata: [String]

    init(maximumNumberOfImages: Int, applicationSupportDirectory: URL) {
        assert(maximumNumberOfImages > 0, "maximumNumberOfImages must be greater than 0")
        self.maximumNumberOfImages = maximumNumberOfImages
        storageLocation = applicationSupportDirectory.appendingPathComponent("UserBackgroundImages")
        setUpStorageDirectory()
        verifyStoredImages()
        availableImages = imagesMetadata.compactMap(UserBackgroundImage.init)
    }

    func addImage(with url: URL) throws {
        let fileName = UUID().uuidString
        let destinationURL = storageLocation.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: url, to: destinationURL)

        guard let image = NSImage(contentsOf: destinationURL) else {
            // pixel
            return
        }

        let colorScheme = calculatePreferredColorScheme(for: image)
        let userBackgroundImage = UserBackgroundImage(fileName: fileName, colorScheme: colorScheme)

        let imagesToDelete = imagesMetadata.suffix(from: maximumNumberOfImages)
        imagesToDelete.forEach { imageMetadata in
            guard let fileName = UserBackgroundImage(imageMetadata)?.fileName else {
                return
            }
            FileManager.default.remove(fileAtURL: storageLocation.appendingPathComponent(imageMetadata))
        }

        imagesMetadata = [userBackgroundImage.description] + imagesMetadata.prefix(maximumNumberOfImages - 1)
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
    func calculatePreferredColorScheme(for image: NSImage) -> ColorScheme {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmapImage.cgImage else { return .light }

        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: nil)

        // Create a grayscale filter
        let grayscaleFilter = CIFilter(name: "CIColorControls")!
        grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
        grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey)

        guard let outputImage = grayscaleFilter.outputImage else { return .light }

        // Create a bitmap representation
        let extent = outputImage.extent
        let bitmap = context.createCGImage(outputImage, from: extent)

        guard let data = bitmap?.dataProvider?.data else { return .light }
        let ptr = CFDataGetBytePtr(data)

        var totalBrightness: CGFloat = 0.0
        let pixelCount = Int(extent.width * extent.height)

        for i in 0..<pixelCount {
            let pixelIndex = i * 4
            let r = CGFloat(ptr![pixelIndex])
            let g = CGFloat(ptr![pixelIndex + 1])
            let b = CGFloat(ptr![pixelIndex + 2])

            // Calculate brightness using the luminance formula
            let brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            totalBrightness += brightness
        }

        let averageBrightness = totalBrightness / CGFloat(pixelCount)
        return averageBrightness > 0.5 ? .light : .dark
    }
}
