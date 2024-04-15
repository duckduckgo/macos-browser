//
//  AddEditBookmarkDialogViewModelMock.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class AddEditBookmarkDialogViewModelMock: BookmarkDialogEditing {
    var bookmarkName: String = ""
    var bookmarkURLPath: String = ""
    var isBookmarkFavorite: Bool = false
    var isURLFieldHidden: Bool = false
    var title: String = ""
    var folders: [DuckDuckGo_Privacy_Browser.FolderViewModel] = []
    var selectedFolder: DuckDuckGo_Privacy_Browser.BookmarkFolder? {
        didSet {
            selectedFolderExpectation?.fulfill()
        }
    }
    var cancelActionTitle: String = ""
    var isOtherActionDisabled: Bool = false
    var defaultActionTitle: String = ""
    var isDefaultActionDisabled: Bool = false

    func cancel(dismiss: () -> Void) {}
    func addOrSave(dismiss: () -> Void) {}

    var selectedFolderExpectation: XCTestExpectation?
}
