//
//  BookmarkStoreMock.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Foundation

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class BookmarkStoreMock: BookmarkStore {

    var loadAllCalled = false
    var bookmarks: [Bookmark]?
    var loadError: Error?
    func loadAll(completion: @escaping ([Bookmark]?, Error?) -> Void) {
        loadAllCalled = true
        completion(bookmarks, loadError)
    }

    var saveCalled = false
    var managedObjectId: NSManagedObjectID?
    var saveSuccess = true
    var saveError: Error?
    func save(bookmark: Bookmark, completion: @escaping (Bool, NSManagedObjectID?, Error?) -> Void) {
        saveCalled = true
        completion(saveSuccess, managedObjectId, saveError)
    }

    var removeCalled = false
    var removeSuccess = true
    var removeError: Error?
    func remove(bookmark: Bookmark, completion: @escaping (Bool, Error?) -> Void) {
        removeCalled = true
        completion(removeSuccess, removeError)
    }

    var updateCalled = false
    func update(bookmark: Bookmark) {
        updateCalled = true
    }

}
