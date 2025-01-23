//
//  CapturingNewTabPageCustomBackgroundProvider.swift
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
import NewTabPage

final class CapturingNewTabPageCustomBackgroundProvider: NewTabPageCustomBackgroundProviding {
    var customizerOpener: NewTabPageCustomizerOpener = NewTabPageCustomizerOpener()

    var customizerData: NewTabPageDataModel.CustomizerData = .init(background: .default, theme: .none, userColor: nil, userImages: [])

    @Published
    var background: NewTabPageDataModel.Background = .default

    var backgroundPublisher: AnyPublisher<NewTabPageDataModel.Background, Never> {
        $background.dropFirst().removeDuplicates().eraseToAnyPublisher()
    }

    @Published
    var theme: NewTabPageDataModel.Theme?

    var themePublisher: AnyPublisher<NewTabPageDataModel.Theme?, Never> {
        $theme.dropFirst().removeDuplicates().eraseToAnyPublisher()
    }

    @Published
    var userImages: [NewTabPageDataModel.UserImage] = []

    var userImagesPublisher: AnyPublisher<[NewTabPageDataModel.UserImage], Never> {
        $userImages.dropFirst().removeDuplicates().eraseToAnyPublisher()
    }

    func presentUploadDialog() async {
        presentUploadDialogCallsCount += 1
    }

    func deleteImage(with imageID: String) async {
        deleteImageCalls.append(imageID)
    }

    func showContextMenu(for imageID: String, using presenter: any NewTabPage.NewTabPageContextMenuPresenting) async {
        showContextMenuCalls.append(imageID)
    }

    var presentUploadDialogCallsCount: Int = 0
    var deleteImageCalls: [String] = []
    var showContextMenuCalls: [String] = []
}
