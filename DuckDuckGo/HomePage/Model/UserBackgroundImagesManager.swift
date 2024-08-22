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
import SwiftUI

struct UserBackgroundImage: Hashable, Equatable, Identifiable, LosslessStringConvertible, ColorSchemeProviding, CustomBackgroundConvertible {
    let fileName: String
    let colorScheme: ColorScheme

    var id: String {
        fileName
    }

    var customBackground: HomePage.Models.SettingsModel.CustomBackground {
        .customImage(self)
    }

    var description: String {
        "\(fileName)|\(colorScheme.description)"
    }

    init(fileName: String, colorScheme: ColorScheme) {
        self.fileName = fileName
        self.colorScheme = colorScheme
    }

    init?(_ description: String) {
        let components = description.split(separator: "|")
        guard components.count == 2, let colorScheme = ColorScheme(String(components[1])) else {
            return nil
        }
        self.fileName = String(components[0])
        self.colorScheme = colorScheme
    }
}

protocol UserBackgroundImagesManaging {
    var storageLocation: URL { get }
    var maximumNumberOfImages: Int { get }
    var availableImages: [UserBackgroundImage] { get }
    var availableImagesPublisher: AnyPublisher<[UserBackgroundImage], Never> { get }

    func addImage(with url: URL) async throws -> UserBackgroundImage
    func deleteImage(_ userBackgroundImage: UserBackgroundImage)
    func image(for userBackgroundImage: UserBackgroundImage) -> NSImage?
    func thumbnailImage(for userBackgroundImage: UserBackgroundImage) -> NSImage?
    func updateSelectedTimestamp(for userBackgroundImage: UserBackgroundImage)
    func sortImagesByLastUsed()
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

final class UserBackgroundImagesManager: UserBackgroundImagesManaging {

    let storageLocation: URL
    private let imageProcessor: ImageProcessing
    private let thumbnailsStorageLocation: URL

    let maximumNumberOfImages: Int

    enum Const {
        static let storageDirectoryName = "UserBackgroundImages"
        static let thumbnailsDirectoryName = "thumbnails"
        static let thumbnailSize = CGSize(width: 192, height: 128)
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

    init(maximumNumberOfImages: Int, applicationSupportDirectory: URL, imageProcessor: ImageProcessing = ImageProcessor()) {
        assert(maximumNumberOfImages > 0, "maximumNumberOfImages must be greater than 0")
        self.maximumNumberOfImages = maximumNumberOfImages
        self.imageProcessor = imageProcessor

        storageLocation = applicationSupportDirectory.appendingPathComponent(Const.storageDirectoryName)
        thumbnailsStorageLocation = storageLocation.appendingPathComponent(Const.thumbnailsDirectoryName)

        do {
            try setUpStorageDirectory(at: storageLocation.path)
            try setUpStorageDirectory(at: thumbnailsStorageLocation.path)
        } catch {
            // fire pixel - failed to initialize storage
        }

        availableImages = imagesMetadata.compactMap(UserBackgroundImage.init)
        verifyStoredImages()
    }

    func addImage(with url: URL) async throws -> UserBackgroundImage {
        let fileName = [UUID().uuidString, "jpg"].joined(separator: ".")
        let destinationURL = storageLocation.appendingPathComponent(fileName)

        try copyImage(at: url, toJPEGAt: destinationURL)

        async let resizeImageTask: Void = {
            let resizedImage: Data? = imageProcessor.resizeImage(at: destinationURL, to: Const.thumbnailSize)
            try resizedImage?.write(to: thumbnailsStorageLocation.appendingPathComponent(fileName))
        }()

        async let colorSchemeTask = {
            imageProcessor.calculatePreferredColorScheme(forImageAt: destinationURL)
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
        let data = try imageProcessor.convertImageToJPEG(at: sourceURL)
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

    private func setUpStorageDirectory(at path: String) throws {
        var isDirectory: ObjCBool = .init(booleanLiteral: false)
        let fileExists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

        switch (fileExists, isDirectory.boolValue) {
        case (true, true):
            return
        case (true, false):
            assertionFailure("File at \(path) is not a directory")
            try FileManager.default.removeItem(atPath: path)
            fallthrough
        case (false, _):
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }

    private func verifyStoredImages() {
        availableImages = availableImages.filter { image in
            let imagePath = storageLocation.appendingPathComponent(image.fileName).path
            return FileManager.default.fileExists(atPath: imagePath)
        }
    }
}
