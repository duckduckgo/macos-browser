//
//  NewTabPageRecentActivityActionsHandling.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

public protocol RecentActivityActionsHandling {

    @MainActor func open(_ url: URL, target: LinkOpenTarget) async
    @MainActor func addFavorite(_ url: URL) async
    @MainActor func removeFavorite(_ url: URL) async
    @MainActor func confirmBurn(_ url: URL) async -> Bool

    var burnDidCompletePublisher: AnyPublisher<Void, Never> { get }
}
