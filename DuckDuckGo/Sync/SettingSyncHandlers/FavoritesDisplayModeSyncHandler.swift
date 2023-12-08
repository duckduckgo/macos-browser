//
//  FavoritesDisplayModeSyncHandler.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Bookmarks
import Combine
import Foundation
import SyncDataProviders

final class FavoritesDisplayModeSyncHandler: FavoritesDisplayModeSyncHandlerBase {

    override func getValue() throws -> String? {
        preferences.favoritesDisplayMode.description
    }

    override func setValue(_ value: String?, shouldDetectOverride: Bool) throws {
        if let value, let displayMode = FavoritesDisplayMode(value) {
            DispatchQueue.main.async {
                self.preferences.favoritesDisplayMode = displayMode
            }
        }
    }

    override var valueDidChangePublisher: AnyPublisher<Void, Never> {
        preferences.$favoritesDisplayMode.dropFirst().asVoid().eraseToAnyPublisher()
    }

    init(_ preferences: AppearancePreferences = .shared) {
        self.preferences = preferences
    }

    private let preferences: AppearancePreferences
}
