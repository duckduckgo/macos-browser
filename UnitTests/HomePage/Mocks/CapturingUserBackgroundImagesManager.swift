//
//  CapturingUserBackgroundImagesManager.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class CapturingUserBackgroundImagesManager: UserBackgroundImagesManaging {

    init(storageLocation: URL, maximumNumberOfImages: Int = HomePage.Models.SettingsModel.Const.maximumNumberOfUserImages) {
        self.storageLocation = storageLocation
        self.maximumNumberOfImages = maximumNumberOfImages
    }

    let storageLocation: URL
    let maximumNumberOfImages: Int

    var imageForUserBackgroundImageCallCount = 0
    var imageForUserBackgroundImage: (UserBackgroundImage) -> NSImage? = { _ in return nil }

    var thumbnailImageForUserBackgroundImageCallCount = 0
    var thumbnailImageForUserBackgroundImage: (UserBackgroundImage) -> NSImage? = { _ in return nil }

    var addImageWithURLCallCount = 0
    var addImageWithURL: (URL) async throws -> UserBackgroundImage = { url in
        return .init(fileName: url.lastPathComponent, colorScheme: .light)
    }

    var deleteImageCallCount = 0
    var deleteImageImpl: (UserBackgroundImage) -> Void = { _ in }

    var updateSelectedTimestampForUserBackgroundImageCallCount = 0
    var updateSelectedTimestampForUserBackgroundImage: (UserBackgroundImage) -> Void = { _ in }

    var sortImagesByLastUsedCallCount = 0
    var sortImagesByLastUsedImpl: () -> Void = {}

    @Published var availableImages: [UserBackgroundImage] = []

    var availableImagesPublisher: AnyPublisher<[UserBackgroundImage], Never> {
        $availableImages.removeDuplicates().eraseToAnyPublisher()
    }

    func image(for userBackgroundImage: UserBackgroundImage) -> NSImage? {
        imageForUserBackgroundImageCallCount += 1
        return imageForUserBackgroundImage(userBackgroundImage)
    }

    func thumbnailImage(for userBackgroundImage: UserBackgroundImage) -> NSImage? {
        thumbnailImageForUserBackgroundImageCallCount += 1
        return thumbnailImageForUserBackgroundImage(userBackgroundImage)
    }

    func addImage(with url: URL) async throws -> UserBackgroundImage {
        addImageWithURLCallCount += 1
        return try await addImageWithURL(url)
    }

    func deleteImage(_ userBackgroundImage: UserBackgroundImage) {
        deleteImageCallCount += 1
        deleteImageImpl(userBackgroundImage)
    }

    func updateSelectedTimestamp(for userBackgroundImage: UserBackgroundImage) {
        updateSelectedTimestampForUserBackgroundImageCallCount += 1
        updateSelectedTimestampForUserBackgroundImage(userBackgroundImage)
    }

    func sortImagesByLastUsed() {
        sortImagesByLastUsedCallCount += 1
        sortImagesByLastUsedImpl()
    }
}
