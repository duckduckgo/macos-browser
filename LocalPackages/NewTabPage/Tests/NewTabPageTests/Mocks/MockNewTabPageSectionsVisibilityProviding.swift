//
//  MockNewTabPageSectionsVisibilityProviding.swift
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

final class MockNewTabPageSectionsVisibilityProvider: NewTabPageSectionsVisibilityProviding {

    @Published var isFavoritesVisible: Bool = true
    @Published var isPrivacyStatsVisible: Bool = true
    @Published var isRecentActivityVisible: Bool = true

    var isFavoritesVisiblePublisher: AnyPublisher<Bool, Never> {
        $isFavoritesVisible.dropFirst().removeDuplicates().eraseToAnyPublisher()
    }
    var isPrivacyStatsVisiblePublisher: AnyPublisher<Bool, Never> {
        $isPrivacyStatsVisible.dropFirst().removeDuplicates().eraseToAnyPublisher()
    }
    var isRecentActivityVisiblePublisher: AnyPublisher<Bool, Never> {
        $isRecentActivityVisible.dropFirst().removeDuplicates().eraseToAnyPublisher()
    }
}
