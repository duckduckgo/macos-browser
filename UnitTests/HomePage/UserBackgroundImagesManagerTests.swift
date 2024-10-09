//
//  UserBackgroundImagesManagerTests.swift
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

@testable import DuckDuckGo_Privacy_Browser
import Foundation
import PixelKit
import XCTest

final class UserBackgroundImagesManagerTests: XCTestCase {

    var manager: UserBackgroundImagesManager!
    var storageLocation: URL!
    var imageProcessor: ImageProcessorMock!
    var sendPixelEvents: [PixelKitEvent] = []

    override func setUp() async throws {
        storageLocation = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        imageProcessor = ImageProcessorMock()

        manager = UserBackgroundImagesManager(
            maximumNumberOfImages: 4,
            applicationSupportDirectory: storageLocation,
            imageProcessor: imageProcessor,
            sendPixel: { [weak self] in self?.sendPixelEvents.append($0) }
        )

        sendPixelEvents = []
    }

    override func tearDown() async throws {
        try FileManager.default.removeItem(at: storageLocation)
        UserDefaultsWrapper<Any>.clearAll()
    }

    func testWhenManagerIsInitializedSucessfullyThenPixelIsNotSent() {
        manager = UserBackgroundImagesManager(
            maximumNumberOfImages: 4,
            applicationSupportDirectory: storageLocation,
            imageProcessor: imageProcessor,
            sendPixel: { [weak self] in self?.sendPixelEvents.append($0) }
        )
        XCTAssertTrue(sendPixelEvents.isEmpty)
    }

    func testWhenManagerFailsToInitializeStorageThenPixelIsSent() {
        manager = UserBackgroundImagesManager(
            maximumNumberOfImages: 4,
            applicationSupportDirectory: URL(fileURLWithPath: "/dev/null"),
            imageProcessor: imageProcessor,
            sendPixel: { [weak self] in self?.sendPixelEvents.append($0) }
        )
        XCTAssertNil(manager)
        XCTAssertEqual(sendPixelEvents.map(\.name), [NewTabBackgroundPixel.newTabBackgroundInitializeStorageError.name])
    }

    func testImageWhenUserImageFileExistsThenNSImageIsReturned() throws {
        let image = NSImage.sampleImage(with: .black)
        try image.save(to: manager.storageLocation.appending("abc.jpg"))
        let userBackgroundImage = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .light)

        XCTAssertNotNil(manager.image(for: userBackgroundImage))
        XCTAssertTrue(sendPixelEvents.isEmpty)
    }

    func testImageWhenUserImageFileDoesNotExistThenNilIsReturned() throws {
        let userBackgroundImage = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .light)

        XCTAssertNil(manager.image(for: userBackgroundImage))
        XCTAssertEqual(sendPixelEvents.map(\.name), [NewTabBackgroundPixel.newTabBackgroundImageNotFound.name])
    }

    func testImageWhenUserImageFileWasManuallyRemovedFromDiskAfterAccessingThenCachedNSImageIsReturned() throws {
        let image = NSImage.sampleImage(with: .black)
        let imageURL = manager.storageLocation.appending("abc.jpg")
        try image.save(to: imageURL)
        let userBackgroundImage = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .light)

        let savedImage = manager.image(for: userBackgroundImage)
        XCTAssertNotNil(savedImage)

        try FileManager.default.removeItem(at: imageURL)
        XCTAssertIdentical(manager.image(for: userBackgroundImage), savedImage)

        XCTAssertTrue(sendPixelEvents.isEmpty)
    }

    func testImageWhenCalledMultipleTimesAndUserImageFileDoesNotExistThenOnlyOnePixelIsSent() throws {
        let userBackgroundImage1 = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .light)
        let userBackgroundImage2 = UserBackgroundImage(fileName: "def.jpg", colorScheme: .light)
        let userBackgroundImage3 = UserBackgroundImage(fileName: "ghi.jpg", colorScheme: .light)

        XCTAssertNil(manager.image(for: userBackgroundImage1))
        XCTAssertNil(manager.image(for: userBackgroundImage1))
        XCTAssertNil(manager.image(for: userBackgroundImage1))
        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabBackgroundPixel.newTabBackgroundImageNotFound.name
        ])

        XCTAssertNil(manager.image(for: userBackgroundImage2))
        XCTAssertNil(manager.image(for: userBackgroundImage2))
        XCTAssertNil(manager.image(for: userBackgroundImage2))
        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabBackgroundPixel.newTabBackgroundImageNotFound.name,
            NewTabBackgroundPixel.newTabBackgroundImageNotFound.name
        ])

        XCTAssertNil(manager.image(for: userBackgroundImage3))
        XCTAssertNil(manager.image(for: userBackgroundImage3))
        XCTAssertNil(manager.image(for: userBackgroundImage3))
        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabBackgroundPixel.newTabBackgroundImageNotFound.name,
            NewTabBackgroundPixel.newTabBackgroundImageNotFound.name,
            NewTabBackgroundPixel.newTabBackgroundImageNotFound.name
        ])
    }

    func testThumbnailImageWhenThumbnailFileExistsThenNSImageIsReturned() throws {
        let image = NSImage.sampleImage(with: .black)
        try image.save(to: manager.thumbnailsStorageLocation.appending("abc.jpg"))
        let userBackgroundImage = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .light)

        XCTAssertNotNil(manager.thumbnailImage(for: userBackgroundImage))
        XCTAssertTrue(sendPixelEvents.isEmpty)
    }

    func testThumbnailImageWhenThumbnailFileDoesNotExistThenImageIsReturned() throws {
        let image = NSImage.sampleImage(with: .black)
        try image.save(to: manager.storageLocation.appending("abc.jpg"))
        let userBackgroundImage = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .light)

        XCTAssertNotNil(manager.thumbnailImage(for: userBackgroundImage))
        XCTAssertEqual(sendPixelEvents.map(\.name), [NewTabBackgroundPixel.newTabBackgroundThumbnailNotFound.name])
    }

    func testThumbnailImageWhenUserImageFileWasManuallyRemovedFromDiskAfterAccessingThenCachedNSImageIsReturned() throws {
        let image = NSImage.sampleImage(with: .black)
        let imageURL = manager.thumbnailsStorageLocation.appending("abc.jpg")
        try image.save(to: imageURL)
        let userBackgroundImage = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .light)

        let savedImage = manager.thumbnailImage(for: userBackgroundImage)
        XCTAssertNotNil(savedImage)

        try FileManager.default.removeItem(at: imageURL)
        XCTAssertIdentical(manager.thumbnailImage(for: userBackgroundImage), savedImage)

        XCTAssertTrue(sendPixelEvents.isEmpty)
    }

    func testThumbnailImageWhenCalledMultipleTimesAndThumbnailFileDoesNotExistThenOnlyOnePixelIsSent() throws {
        let image = NSImage.sampleImage(with: .black)
        try image.save(to: manager.storageLocation.appending("abc.jpg"))
        try image.save(to: manager.storageLocation.appending("def.jpg"))
        try image.save(to: manager.storageLocation.appending("ghi.jpg"))

        let userBackgroundImage1 = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .light)
        let userBackgroundImage2 = UserBackgroundImage(fileName: "def.jpg", colorScheme: .light)
        let userBackgroundImage3 = UserBackgroundImage(fileName: "ghi.jpg", colorScheme: .light)

        XCTAssertNotNil(manager.thumbnailImage(for: userBackgroundImage1))
        XCTAssertNotNil(manager.thumbnailImage(for: userBackgroundImage1))
        XCTAssertNotNil(manager.thumbnailImage(for: userBackgroundImage1))
        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabBackgroundPixel.newTabBackgroundThumbnailNotFound.name
        ])

        XCTAssertNotNil(manager.thumbnailImage(for: userBackgroundImage2))
        XCTAssertNotNil(manager.thumbnailImage(for: userBackgroundImage2))
        XCTAssertNotNil(manager.thumbnailImage(for: userBackgroundImage2))
        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabBackgroundPixel.newTabBackgroundThumbnailNotFound.name,
            NewTabBackgroundPixel.newTabBackgroundThumbnailNotFound.name
        ])

        XCTAssertNotNil(manager.thumbnailImage(for: userBackgroundImage3))
        XCTAssertNotNil(manager.thumbnailImage(for: userBackgroundImage3))
        XCTAssertNotNil(manager.thumbnailImage(for: userBackgroundImage3))
        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabBackgroundPixel.newTabBackgroundThumbnailNotFound.name,
            NewTabBackgroundPixel.newTabBackgroundThumbnailNotFound.name,
            NewTabBackgroundPixel.newTabBackgroundThumbnailNotFound.name
        ])
    }

    func testThatAvailableImagesAreSortedByLastAdded() async throws {
        let image = NSImage.sampleImage(with: .black)
        let imageURL = storageLocation.appending("abc.jpg")
        try image.save(to: imageURL)

        let image1 = try await manager.addImage(with: imageURL)
        let image2 = try await manager.addImage(with: imageURL)
        let image3 = try await manager.addImage(with: imageURL)

        XCTAssertEqual(manager.availableImages, [image3, image2, image1])
    }

    func testThatUpdateSelectedTimestampMovesImageToTheFrontOfAvailableImages() async throws {
        let image = NSImage.sampleImage(with: .black)
        let imageURL = storageLocation.appending("abc.jpg")
        try image.save(to: imageURL)

        let image1 = try await manager.addImage(with: imageURL)
        let image2 = try await manager.addImage(with: imageURL)
        let image3 = try await manager.addImage(with: imageURL)

        manager.updateSelectedTimestamp(for: image1)
        manager.sortImagesByLastUsed()
        XCTAssertEqual(manager.availableImages, [image1, image3, image2])

        manager.updateSelectedTimestamp(for: image2)
        manager.sortImagesByLastUsed()
        XCTAssertEqual(manager.availableImages, [image2, image1, image3])

        manager.updateSelectedTimestamp(for: image1)
        manager.sortImagesByLastUsed()
        XCTAssertEqual(manager.availableImages, [image1, image2, image3])

        manager.updateSelectedTimestamp(for: image3)
        manager.sortImagesByLastUsed()
        XCTAssertEqual(manager.availableImages, [image3, image1, image2])
    }

    func testWhenAddImageCompletesSuccessfullyThenNewImageIsAdded() async throws {
        let image = NSImage.sampleImage(with: .black)
        let imageURL = storageLocation.appending("abc.jpg")
        try image.save(to: imageURL)

        // Don't mock image processor in order to enable actual processing
        manager = UserBackgroundImagesManager(
            maximumNumberOfImages: 4,
            applicationSupportDirectory: storageLocation,
            sendPixel: { [weak self] in self?.sendPixelEvents.append($0) }
        )

        let userBackgroundImage = try await manager.addImage(with: imageURL)
        XCTAssertEqual(sendPixelEvents.map(\.name), [NewTabBackgroundPixel.newTabBackgroundAddedUserImage.name])

        XCTAssertEqual(manager.availableImages, [userBackgroundImage])

        XCTAssertNotNil(manager.image(for: userBackgroundImage))
        XCTAssertNotNil(manager.thumbnailImage(for: userBackgroundImage))
    }

    func testWhenImagesAreOverTheLimitThenOldImagesAreDeleted() async throws {
        let image = NSImage.sampleImage(with: .black)
        let imageURL = storageLocation.appending("abc.jpg")
        try image.save(to: imageURL)

        var userBackgroundImages: [UserBackgroundImage] = []
        userBackgroundImages.append(try await manager.addImage(with: imageURL))
        userBackgroundImages.append(try await manager.addImage(with: imageURL))
        userBackgroundImages.append(try await manager.addImage(with: imageURL))
        userBackgroundImages.append(try await manager.addImage(with: imageURL))
        userBackgroundImages.append(try await manager.addImage(with: imageURL))

        XCTAssertEqual(sendPixelEvents.map(\.name), Array(repeating: NewTabBackgroundPixel.newTabBackgroundAddedUserImage.name, count: 5))
        XCTAssertEqual(manager.availableImages, Array(userBackgroundImages[1...4].reversed()))
    }

    func testAddImageWhenCopyingImageFailsThenNewImageIsNotAdded() async throws {
        struct CopyImageError: Error {}

        let image = NSImage.sampleImage(with: .black)
        let imageURL = storageLocation.appending("abc.jpg")
        try image.save(to: imageURL)

        imageProcessor.convertImageToJPEG = { _ in throw CopyImageError() }

        do {
            _ = try await manager.addImage(with: imageURL)
            XCTFail("Expected to throw an error")
        } catch {
            XCTAssertTrue(manager.availableImages.isEmpty)
        }
    }

    func testAddImageWhenThumbnailCreationFailsThenPixelIsSentAndNewImageIsStillAdded() async throws {
        struct ThumbnailGenerationError: Error {}

        let image = NSImage.sampleImage(with: .black)
        let imageURL = storageLocation.appending("abc.jpg")
        try image.save(to: imageURL)

        let defaultImageProcessor = ImageProcessor()

        imageProcessor.convertImageToJPEG = { try defaultImageProcessor.convertImageToJPEG(at: $0) }
        imageProcessor.resizeImage = { data, size in
            if size == UserBackgroundImagesManager.Const.thumbnailSize {
                throw ThumbnailGenerationError()
            }
            return try defaultImageProcessor.resizeImage(with: data, to: size)
        }

        let userBackgroundImage = try await manager.addImage(with: imageURL)
        XCTAssertEqual(sendPixelEvents.map(\.name), [
            NewTabBackgroundPixel.newTabBackgroundThumbnailGenerationError.name,
            NewTabBackgroundPixel.newTabBackgroundAddedUserImage.name
        ])

        XCTAssertEqual(manager.availableImages, [userBackgroundImage])

        XCTAssertNotNil(manager.image(for: userBackgroundImage))

        // verify that when thumbnail is requested then the original image is returned
        XCTAssertEqual(
            manager.thumbnailImage(for: userBackgroundImage)?.tiffRepresentation,
            manager.image(for: userBackgroundImage)?.tiffRepresentation
        )
    }

    func testWhenDeleteImageIsPassedExistingImageThenImageIsRemovedAndFilesAreDeleted() async throws {
        let image = NSImage.sampleImage(with: .black)
        let imageURL = storageLocation.appending("abc.jpg")
        try image.save(to: imageURL)

        // Don't mock image processor in order to enable actual processing
        manager = UserBackgroundImagesManager(
            maximumNumberOfImages: 4,
            applicationSupportDirectory: storageLocation,
            sendPixel: { [weak self] in self?.sendPixelEvents.append($0) }
        )

        let userBackgroundImage1 = try await manager.addImage(with: imageURL)
        let userBackgroundImage2 = try await manager.addImage(with: imageURL)
        sendPixelEvents.removeAll()

        // WHEN
        manager.deleteImage(userBackgroundImage2)

        // THEN
        XCTAssertEqual(sendPixelEvents.map(\.name), [NewTabBackgroundPixel.newTabBackgroundDeletedUserImage.name])

        XCTAssertEqual(manager.availableImages, [userBackgroundImage1])
        XCTAssertNil(manager.image(for: userBackgroundImage2))
        XCTAssertNil(manager.thumbnailImage(for: userBackgroundImage2))
    }

    func testWhenDeleteImageIsPassedUnknownImageThenItPerformsNoAction() async throws {
        let image = NSImage.sampleImage(with: .black)
        let imageURL = storageLocation.appending("abc.jpg")
        try image.save(to: imageURL)

        // Don't mock image processor in order to enable actual processing
        manager = UserBackgroundImagesManager(
            maximumNumberOfImages: 4,
            applicationSupportDirectory: storageLocation,
            sendPixel: { [weak self] in self?.sendPixelEvents.append($0) }
        )

        let userBackgroundImage1 = try await manager.addImage(with: imageURL)
        let userBackgroundImage2 = UserBackgroundImage(fileName: UUID().uuidString, colorScheme: .dark)
        sendPixelEvents.removeAll()

        // WHEN
        manager.deleteImage(userBackgroundImage2)

        // THEN
        XCTAssertTrue(sendPixelEvents.isEmpty)

        XCTAssertEqual(manager.availableImages, [userBackgroundImage1])
        XCTAssertNil(manager.image(for: userBackgroundImage2))
        XCTAssertNil(manager.thumbnailImage(for: userBackgroundImage2))
    }
}

fileprivate extension NSImage {

    func save(to fileURL: URL, as fileType: NSBitmapImageRep.FileType = .jpeg) throws {
        let tiffData = tiffRepresentation!
        let bitmapImageRep = NSBitmapImageRep(data: tiffData)!
        let imageData = bitmapImageRep.representation(using: fileType, properties: [:])!

        try imageData.write(to: fileURL)
    }

    static func sampleImage(with color: NSColor) -> NSImage {
        // Create a 1x1 pixel bitmap image representation
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!

        // Lock focus on the bitmap representation to draw into it
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

        // Set the color of the single pixel
        color.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()

        // Unlock focus
        NSGraphicsContext.restoreGraphicsState()

        // Create an NSImage and add the bitmap representation to it
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.addRepresentation(bitmapRep)

        return image
    }
}
