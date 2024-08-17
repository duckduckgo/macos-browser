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

import AppKitExtensions
import Combine
import CoreImage
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct UserBackgroundImage: Hashable, Equatable, Identifiable, ColorSchemeProviding {
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
    var availableImagesPublisher: AnyPublisher<[UserBackgroundImage], Never> { get }

    func addImage(with url: URL) async throws -> UserBackgroundImage?
    func deleteImage(_ userBackgroundImage: UserBackgroundImage)
    func image(for userBackgroundImage: UserBackgroundImage) -> NSImage?
    func thumbnailImage(for userBackgroundImage: UserBackgroundImage) -> NSImage?
    func updateSelectedTimestamp(for userBackgroundImage: UserBackgroundImage)
    func sortImagesByLastUsed()
}

protocol ImageColorSchemeCalculating {
    func calculatePreferredColorScheme(forImageAt url: URL) -> ColorScheme
}

protocol ImageProcessing {
    func convertImageToJPEG(at url: URL) -> Data?
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
        let components = description.split(separator: "|")
        guard components.count == 2, let colorScheme = ColorScheme(String(components[1])) else {
            return nil
        }
        self.fileName = String(components[0])
        self.colorScheme = colorScheme
    }

    var description: String {
        "\(fileName)|\(colorScheme.description)"
    }
}

final class UserBackgroundImagesManager: UserBackgroundImagesManaging {

    let storageLocation: URL
    private let thumbnailsStorageLocation: URL

    let maximumNumberOfImages: Int

    enum Const {
        static let storageDirectoryName = "UserBackgroundImages"
        static let thumbnailsDirectoryName = "thumbnails"
    }

    @Published private(set) var availableImages: [UserBackgroundImage] = [] {
        didSet {
            if availableImagesSortedByAccessTime != availableImages {
                availableImagesSortedByAccessTime = availableImages
            }
        }
    }

    var availableImagesPublisher: AnyPublisher<[UserBackgroundImage], Never> {
        $availableImages.removeDuplicates().eraseToAnyPublisher()
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
        thumbnailsStorageLocation = storageLocation.appendingPathComponent(Const.thumbnailsDirectoryName)

        setUpStorageDirectory(at: storageLocation.path)
        setUpStorageDirectory(at: thumbnailsStorageLocation.path)

        availableImages = imagesMetadata.compactMap(UserBackgroundImage.init)
        verifyStoredImages()
    }

    func addImage(with url: URL) async throws -> UserBackgroundImage? {
        let fileName = [UUID().uuidString, "jpg"].joined(separator: ".")
        let destinationURL = storageLocation.appendingPathComponent(fileName)

        try copyImage(at: url, toJPEGAt: destinationURL)

        async let resizeImageTask: Void = {
            let date = Date()
            let resizedImage: Data? = resizeImage(at: destinationURL, to: .init(width: 192, height: 128))
            try resizedImage?.write(to: thumbnailsStorageLocation.appendingPathComponent(fileName))
            print("Resizing \(fileName) took \(Date().timeIntervalSince(date)) seconds")
        }()

        async let colorSchemeTask = {
            calculatePreferredColorScheme(forImageAt: destinationURL)
        }()

        try await resizeImageTask
        let colorScheme = await colorSchemeTask

        deleteOldImages()

        let userBackgroundImage = UserBackgroundImage(fileName: fileName, colorScheme: colorScheme)
        imagesMetadata = [userBackgroundImage.description] + imagesMetadata.prefix(maximumNumberOfImages - 1)
        return userBackgroundImage
    }

    func deleteImage(_ userBackgroundImage: UserBackgroundImage) {
        guard let index = imagesMetadata.firstIndex(of: userBackgroundImage.description) else {
            return
        }
        imagesMetadata.remove(at: index)
        deleteImages(for: userBackgroundImage)
    }

    private func copyImage(at sourceURL: URL, toJPEGAt destinationURL: URL) throws {
        guard let data = convertImageToJPEG(at: sourceURL) else {
            // throw error
            return
        }
        try data.write(to: destinationURL)
    }

    private func deleteOldImages() {
        guard imagesMetadata.count >= maximumNumberOfImages else {
            return
        }
        let imagesToDelete = imagesMetadata.suffix(from: maximumNumberOfImages - 1).compactMap(UserBackgroundImage.init)
        imagesToDelete.forEach { deleteImages(for: $0) }
    }

    private func deleteImages(for userBackgroundImage: UserBackgroundImage) {
        FileManager.default.remove(fileAtURL: storageLocation.appendingPathComponent(userBackgroundImage.fileName))
        FileManager.default.remove(fileAtURL: thumbnailsStorageLocation.appendingPathComponent(userBackgroundImage.fileName))
    }

    func image(for userBackgroundImage: UserBackgroundImage) -> NSImage? {
        NSImage(contentsOf: storageLocation.appendingPathComponent(userBackgroundImage.fileName))
    }

    func thumbnailImage(for userBackgroundImage: UserBackgroundImage) -> NSImage? {
        NSImage(
            contentsOf: storageLocation
                .appendingPathComponent(Const.thumbnailsDirectoryName)
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

    func sortImagesByLastUsed() {
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

extension UserBackgroundImagesManager: ImageProcessing {

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
            transform = transform.translatedBy(x: height, y: 0)
            transform = transform.rotated(by: .pi / 2)
            transform = transform.scaledBy(x: width/height, y: height/width)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: width)
            transform = transform.rotated(by: -.pi / 2)
            transform = transform.scaledBy(x: width/height, y: height/width)
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

        let contextSize: CGSize = {
            switch orientation {
            case .left, .leftMirrored, .right, .rightMirrored:
                CGSize(width: height, height: width)
            default:
                CGSize(width: width, height: height)
            }
        }()

        guard let context = CGContext(
            data: nil,
            width: Int(contextSize.width),
            height: Int(contextSize.height),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: cgImage.bytesPerRow,
            space: cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) else {
            // pixel/error
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

    func convertImageToJPEG(at url: URL) -> Data? {
        // Create a CGImageSource from the source image data
        guard let data = try? Data(contentsOf: url),
              let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            // pixel/error
            return nil
        }

        // Create a mutable data object to hold the JPEG data
        let mutableData = NSMutableData()

        // Create a CGImageDestination for the JPEG format
        guard let imageDestination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            // pixel/error
            return nil
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        let orientationRawValue = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: orientationRawValue) ?? .up

        guard let correctedCGImage = correctImageOrientation(cgImage: cgImage, orientation: orientation) else {
            // pixel/error
            return nil
        }

        // Add the CGImage to the destination
        CGImageDestinationAddImage(imageDestination, correctedCGImage, nil)

        // Finalize the image destination to write the data
        guard CGImageDestinationFinalize(imageDestination) else {
            // pixel/error
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
            // pixel/error
            return data
        }

        let context = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: originalImage.bitsPerComponent,
            bytesPerRow: originalImage.bytesPerRow,
            space: originalImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )

        context?.draw(croppedImage, in: CGRect(origin: .zero, size: newSize))

        guard let resizedImage = context?.makeImage() else {
            // pixel/error
            return data
        }

        let mutableData = NSMutableData()
        guard let imageDestination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            // pixel/error
            return data
        }

        CGImageDestinationAddImage(imageDestination, resizedImage, nil)
        CGImageDestinationFinalize(imageDestination)

        return mutableData as Data
    }

}
