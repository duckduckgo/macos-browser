//
//  AppearancePreferences+NewTabPage.swift
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

extension AppearancePreferences: NewTabPageSectionsVisibilityProviding {
    var isFavoritesVisible: Bool {
        get {
            isFavoriteVisible
        }
        set {
            isFavoriteVisible = newValue
        }
    }

    var isPrivacyStatsVisible: Bool {
        get {
            isRecentActivityVisible
        }
        set {
            isRecentActivityVisible = newValue
        }
    }

    var isFavoritesVisiblePublisher: AnyPublisher<Bool, Never> {
        $isFavoriteVisible.dropFirst().removeDuplicates().eraseToAnyPublisher()
    }

    var isPrivacyStatsVisiblePublisher: AnyPublisher<Bool, Never> {
        $isRecentActivityVisible.dropFirst().removeDuplicates().eraseToAnyPublisher()
    }
}
