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
    func previewImage(for userBackgroundImage: UserBackgroundImage) -> NSImage?
    func updateSelectedTimestamp(for userBackgroundImage: UserBackgroundImage)
    func sortImages()
}

protocol ImageColorSchemeCalculating {
    func calculatePreferredColorScheme(forImageAt url: URL) -> ColorScheme
}

protocol ImageResizng {
    func resizeImage(at url: URL, to newSize: CGSize) -> Data?
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
    private let previewsStorageLocation: URL

    let maximumNumberOfImages: Int

    enum Const {
        static let storageDirectoryName = "UserBackgroundImages"
        static let previewsDirectoryName = "previews"
    }

    private(set) var availableImages: [UserBackgroundImage] = [] {
        didSet {
            if availableImagesSortedByAccessTime != availableImages {
                availableImagesSortedByAccessTime = availableImages
            }
        }
    }

    private var availableImagesSortedByAccessTime: [UserBackgroundImage] = []

    @UserDefaultsWrapper(key: .homePageUserBackgroundImages, defaultValue: [])
    private var imagesMetadata: [String] {
        didSet {
            availableImages = imagesMetadata.compactMap(UserBackgroundImage.init)
        }
    }

    init(maximumNumberOfImages: Int, applicationSupportDirectory: URL) {
        assert(maximumNumberOfImages > 0, "maximumNumberOfImages must be greater than 0")
        self.maximumNumberOfImages = maximumNumberOfImages
        storageLocation = applicationSupportDirectory.appendingPathComponent(Const.storageDirectoryName)
        previewsStorageLocation = storageLocation.appendingPathComponent(Const.previewsDirectoryName)

        setUpStorageDirectory(at: storageLocation.path)
        setUpStorageDirectory(at: previewsStorageLocation.path)

        availableImages = imagesMetadata.compactMap(UserBackgroundImage.init)
        verifyStoredImages()
    }

    func addImage(with url: URL) async throws -> UserBackgroundImage? {
        let fileExtension = url.pathExtension
        let isHEIC = fileExtension.lowercased() == "heic"
        let destinationExtension = isHEIC ? "jpg" : fileExtension

        let fileName = [UUID().uuidString, destinationExtension].joined(separator: ".")
        let destinationURL = storageLocation.appendingPathComponent(fileName)
        if fileExtension.lowercased() == "heic" {
            try copyHEIC(at: url, toJPEGAt: destinationURL)
        } else {
            try FileManager.default.copyItem(at: url, to: destinationURL)
        }

        async let resizeImageTask: Void = {
            let date = Date()
            let resizedImage: Data? = resizeImage(at: destinationURL, to: .init(width: 192, height: 128))
            try resizedImage?.write(to: previewsStorageLocation.appendingPathComponent(fileName))
            print("Resizing took \(Date().timeIntervalSince(date)) seconds")
        }()

        async let colorSchemeTask = {
            calculatePreferredColorScheme(forImageAt: destinationURL)
        }()

        try await resizeImageTask
        let colorScheme = await colorSchemeTask

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

    func previewImage(for userBackgroundImage: UserBackgroundImage) -> NSImage? {
        NSImage(
            contentsOf: storageLocation
                .appendingPathComponent(Const.previewsDirectoryName)
                .appendingPathComponent(userBackgroundImage.fileName)
        )
    }

    func updateSelectedTimestamp(for userBackgroundImage: UserBackgroundImage) {
        guard let index = availableImagesSortedByAccessTime.firstIndex(of: userBackgroundImage) else {
            assertionFailure("selected image is not present in available images")
            return
        }
        var images = availableImagesSortedByAccessTime
        images.remove(at: index)
        availableImagesSortedByAccessTime = [userBackgroundImage] + images
    }

    func sortImages() {
        imagesMetadata = availableImagesSortedByAccessTime.map(\.description)
    }

    private func setUpStorageDirectory(at path: String) {
        var isDirectory: ObjCBool = .init(booleanLiteral: false)
        let fileExists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

        switch (fileExists, isDirectory.boolValue) {
        case (true, true):
            return
        case (true, false):
            assertionFailure("File at \(path) is not a directory")
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                // fire pixel
            }
            fallthrough
        case (false, _):
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
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

extension UserBackgroundImagesManager: ImageResizng {

    func copyHEIC(at sourceURL: URL, toJPEGAt destinationURL: URL) throws {
        guard let data = convertHEICToJPEG(at: sourceURL) else {
            // throw error
            return
        }
        try data.write(to: destinationURL)
    }

    func correctImageOrientation(cgImage: CGImage, orientation: CGImagePropertyOrientation) -> CGImage? {
        var transform = CGAffineTransform.identity
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        switch orientation {
        case .up, .upMirrored:
            return cgImage
        case .down, .downMirrored:
            transform = transform.translatedBy(x: width, y: height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: height)
            transform = transform.rotated(by: -.pi / 2)
        }

        switch orientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }

        let contextWidth: Int, contextHeight: Int
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            contextWidth = Int(height)
            contextHeight = Int(width)
        default:
            contextWidth = Int(width)
            contextHeight = Int(height)
        }

        guard let context = CGContext(
            data: nil,
            width: contextWidth,
            height: contextHeight,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.concatenate(transform)

        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: height, height: width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        return context.makeImage()
    }

    func convertHEICToJPEG(at url: URL) -> Data? {
        // Create a CGImageSource from the HEIC data
        guard let data = try? Data(contentsOf: url),
              let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }

        // Create a mutable data object to hold the JPEG data
        let mutableData = NSMutableData()

        // Create a CGImageDestination for the JPEG format
        guard let imageDestination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, nil) else {
            return nil
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        let orientationRawValue = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: orientationRawValue) ?? .up

        guard let correctedCGImage = correctImageOrientation(cgImage: cgImage, orientation: orientation) else {
            return nil
        }

        // Add the CGImage to the destination
        CGImageDestinationAddImage(imageDestination, correctedCGImage, nil)

        // Finalize the image destination to write the data
        guard CGImageDestinationFinalize(imageDestination) else {
            return nil
        }

        return mutableData as Data
    }

    func resizeImage(at url: URL, to newSize: CGSize) -> Data? {
        guard let data = try? Data(contentsOf: url),
              let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let originalImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            return nil
        }

        let originalWidth = CGFloat(originalImage.width)
        let originalHeight = CGFloat(originalImage.height)

        let widthRatio = newSize.width / originalWidth
        let heightRatio = newSize.height / originalHeight
        let scale = max(widthRatio, heightRatio)

        let scaledWidth = newSize.width / scale
        let scaledHeight = newSize.height / scale

        let xOffset = (originalWidth - scaledWidth) / 2
        let yOffset = (originalHeight - scaledHeight) / 2

        let cropRect = CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight)

        guard let croppedImage = originalImage.cropping(to: cropRect) else {
            return nil
        }

        let context = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: originalImage.bitsPerComponent,
            bytesPerRow: 0,
            space: originalImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )

        context?.draw(croppedImage, in: CGRect(origin: .zero, size: newSize))

        guard let resizedImage = context?.makeImage() else {
            return nil
        }

        let mutableData = NSMutableData()
        guard let imageDestination = CGImageDestinationCreateWithData(mutableData, kUTTypePNG, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImage(imageDestination, resizedImage, nil)
        CGImageDestinationFinalize(imageDestination)

        return mutableData as Data
    }

}

extension NSImage {
    func averageBrightness(sampleSize: Int = 2048) -> CGFloat? {
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
