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

import Combine
import Foundation
import os.log
import PixelKit
import SwiftUI

protocol UserBackgroundImagesManaging {
    var storageLocation: URL { get }
    var maximumNumberOfImages: Int { get }
    var availableImages: [UserBackgroundImage] { get }
    var availableImagesPublisher: AnyPublisher<[UserBackgroundImage], Never> { get }

    func image(for userBackgroundImage: UserBackgroundImage) -> NSImage?
    func thumbnailImage(for userBackgroundImage: UserBackgroundImage) -> NSImage?

    func addImage(with url: URL) async throws -> UserBackgroundImage
    func deleteImage(_ userBackgroundImage: UserBackgroundImage)

    func updateSelectedTimestamp(for userBackgroundImage: UserBackgroundImage)
    func sortImagesByLastUsed()
}

final class UserBackgroundImagesManager: UserBackgroundImagesManaging {

    enum Const {
        static let storageDirectoryName = "UserBackgroundImages"
        static let thumbnailsDirectoryName = "thumbnails"
        static let thumbnailSize = CGSize(width: 192, height: 128)
        static let jpegExtension = "jpg"
    }

    let maximumNumberOfImages: Int
    let storageLocation: URL
    let thumbnailsStorageLocation: URL
    private let sendPixel: (PixelKitEvent) -> Void
    private let imageProcessor: ImageProcessing
    private var availableImagesSortedByAccessTime: [UserBackgroundImage] = []

    /**
     * This set contains names of files for which `NSImage` couldn't be fetched.
     *
     * Whenever `image(for:)` or `thumbnailImage(for:)` failes to return an `NSImage`
     * a pixel is sent. To avoid sending multiple pixels per single image, this set keeps
     * track of image file names in order to ensure the pixels are sent only once per image
     * per app session.
     */
    private var pathsForNotFoundImages: Set<String> = []

    var availableImagesPublisher: AnyPublisher<[UserBackgroundImage], Never> {
        $availableImages.removeDuplicates().eraseToAnyPublisher()
    }

    @Published private(set) var availableImages: [UserBackgroundImage] = [] {
        didSet {
            if availableImagesSortedByAccessTime != availableImages {
                availableImagesSortedByAccessTime = availableImages
            }
        }
    }

    @UserDefaultsWrapper(key: .homePageUserBackgroundImages, defaultValue: [])
    private var imagesMetadata: [String] {
        didSet {
            availableImages = imagesMetadata.compactMap(UserBackgroundImage.init)
        }
    }

    init?(
        maximumNumberOfImages: Int,
        applicationSupportDirectory: URL,
        imageProcessor: ImageProcessing = ImageProcessor(),
        sendPixel: @escaping (PixelKitEvent) -> Void = { PixelKit.fire($0) }
    ) {
        assert(maximumNumberOfImages > 0, "maximumNumberOfImages must be greater than 0")
        self.maximumNumberOfImages = maximumNumberOfImages
        self.imageProcessor = imageProcessor
        self.sendPixel = sendPixel

        storageLocation = applicationSupportDirectory.appendingPathComponent(Const.storageDirectoryName)
        thumbnailsStorageLocation = storageLocation.appendingPathComponent(Const.thumbnailsDirectoryName)

        do {
            try setUpStorageDirectory(at: storageLocation.path)
            try setUpStorageDirectory(at: thumbnailsStorageLocation.path)

            availableImages = imagesMetadata.compactMap(UserBackgroundImage.init)
            validateAvailableImages()
        } catch {
            Logger.homePageSettings.error("Failed to initialize user background images storage: \(error)")
            sendPixel(DebugEvent(NewTabBackgroundPixel.newTabBackgroundInitializeStorageError, error: error))
            return nil
        }
    }

    /**
     * These caches store up to 4 images each, as enforced by the app UI where you can't add more images.
     */
    private var imagesCache: [UserBackgroundImage: NSImage] = [:]
    private var thumbnailsCache: [UserBackgroundImage: NSImage] = [:]

    func image(for userBackgroundImage: UserBackgroundImage) -> NSImage? {
        if let cachedImage = imagesCache[userBackgroundImage] {
            return cachedImage
        }

        let imagePath = storageLocation.appendingPathComponent(userBackgroundImage.fileName).path
        guard let image = NSImage(contentsOfFile: imagePath) else {
            if !pathsForNotFoundImages.contains(imagePath) {
                pathsForNotFoundImages.insert(imagePath)
                sendPixel(DebugEvent(NewTabBackgroundPixel.newTabBackgroundImageNotFound))
            }
            Logger.homePageSettings.error("Image for \(userBackgroundImage.fileName) not found")
            return nil
        }
        imagesCache[userBackgroundImage] = image
        return image
    }

    func thumbnailImage(for userBackgroundImage: UserBackgroundImage) -> NSImage? {
        if let cachedThumbnail = thumbnailsCache[userBackgroundImage] {
            return cachedThumbnail
        }

        let thumbnailPath = thumbnailsStorageLocation.appendingPathComponent(userBackgroundImage.fileName).path
        guard let thumbnail = NSImage(contentsOfFile: thumbnailPath) else {
            if !pathsForNotFoundImages.contains(thumbnailPath) {
                pathsForNotFoundImages.insert(thumbnailPath)
                sendPixel(DebugEvent(NewTabBackgroundPixel.newTabBackgroundThumbnailNotFound))
            }
            Logger.homePageSettings.error("Thumbnail for \(userBackgroundImage.fileName) not found, using full-size image as thumbnail")
            return image(for: userBackgroundImage)
        }
        thumbnailsCache[userBackgroundImage] = thumbnail
        return thumbnail
    }

    func addImage(with url: URL) async throws -> UserBackgroundImage {
        let fileName = [UUID().uuidString, Const.jpegExtension].joined(separator: ".")
        let destinationURL = storageLocation.appendingPathComponent(fileName)
        Logger.homePageSettings.debug("Processing user image at \(url.path) -> \(fileName) ...")

        // first copy the image, converting it to JPEG
        try copyImage(at: url, toJPEGAt: destinationURL)

        // then spawn 2 concurrent tasks:
        // thumbnail generation
        async let thumbnailTask: Void = {
            do {
                let imageData = try Data(contentsOf: destinationURL)
                let resizedImageData = try imageProcessor.resizeImage(with: imageData, to: Const.thumbnailSize)
                Logger.homePageSettings.debug("Thumbnail for \(destinationURL.lastPathComponent) generated")

                try resizedImageData.write(to: thumbnailsStorageLocation.appendingPathComponent(fileName))
                Logger.homePageSettings.debug("Thumbnail for \(destinationURL.lastPathComponent) saved in application data directory")
            } catch {
                Logger.homePageSettings.error("Failed to generate thumbnail for \(destinationURL.lastPathComponent): \(error)")
                sendPixel(DebugEvent(NewTabBackgroundPixel.newTabBackgroundThumbnailGenerationError, error: error))
            }
        }()

        // and color scheme calculation
        async let colorSchemeTask = {
            let colorScheme = imageProcessor.calculatePreferredColorScheme(forImageAt: destinationURL)
            Logger.homePageSettings.debug("Preferred color scheme for \(destinationURL.lastPathComponent) is \(colorScheme)")
            return colorScheme
        }()

        await thumbnailTask
        let colorScheme = await colorSchemeTask

        deleteImagesOverLimit()

        sendPixel(NewTabBackgroundPixel.newTabBackgroundAddedUserImage)

        let userBackgroundImage = UserBackgroundImage(fileName: fileName, colorScheme: colorScheme)
        imagesMetadata = [userBackgroundImage.description] + imagesMetadata.prefix(maximumNumberOfImages - 1)
        return userBackgroundImage
    }

    func deleteImage(_ userBackgroundImage: UserBackgroundImage) {
        guard let index = imagesMetadata.firstIndex(of: userBackgroundImage.description) else {
            return
        }
        imagesMetadata.remove(at: index)
        deleteImageFiles(for: userBackgroundImage)

        sendPixel(NewTabBackgroundPixel.newTabBackgroundDeletedUserImage)
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

    private func copyImage(at sourceURL: URL, toJPEGAt destinationURL: URL) throws {
        let data = try imageProcessor.convertImageToJPEG(at: sourceURL)
        Logger.homePageSettings.debug("Image \(destinationURL.lastPathComponent) processed")
        try data.write(to: destinationURL)
        Logger.homePageSettings.debug("Image \(destinationURL.lastPathComponent) saved in application data directory")
    }

    private func deleteImagesOverLimit() {
        guard imagesMetadata.count >= maximumNumberOfImages else {
            return
        }
        Logger.homePageSettings.debug("User images are over limit, deleting oldest image(s) ...")
        let imagesToDelete = imagesMetadata.suffix(from: maximumNumberOfImages - 1).compactMap(UserBackgroundImage.init)
        imagesToDelete.forEach { deleteImageFiles(for: $0) }
    }

    private func deleteImageFiles(for userBackgroundImage: UserBackgroundImage) {
        FileManager.default.remove(fileAtURL: storageLocation.appendingPathComponent(userBackgroundImage.fileName))
        FileManager.default.remove(fileAtURL: thumbnailsStorageLocation.appendingPathComponent(userBackgroundImage.fileName))
        imagesCache.removeValue(forKey: userBackgroundImage)
        thumbnailsCache.removeValue(forKey: userBackgroundImage)
        Logger.homePageSettings.debug("Deleted user background image files for \(userBackgroundImage.fileName)")
    }

    private func setUpStorageDirectory(at path: String) throws {
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

        switch (fileExists, isDirectory.boolValue) {
        case (true, true):
            Logger.homePageSettings.info("User background images storage directory is ready for use at \(path)")
            return
        case (true, false):
            // File found where directory was expected
            // Because we're inside the application data directory, we claim ownership
            // over files inside it and proceed with deleting the file.
            Logger.homePageSettings.info("Deleting file at \(path) in order to prepare user background images storage")
            try FileManager.default.removeItem(atPath: path)
            fallthrough
        case (false, _):
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            Logger.homePageSettings.info("User background images storage directory created \(path)")
        }
    }

    private func validateAvailableImages() {
        availableImages = availableImages.filter { image in
            let imagePath = storageLocation.appendingPathComponent(image.fileName).path
            if FileManager.default.fileExists(atPath: imagePath) {
                return true
            }
            Logger.homePageSettings.debug("User background image \(image.fileName) not found in storage, removing from the list of available images")
            return false
        }
    }
}
