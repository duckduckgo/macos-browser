//
//  CapturingRecentActivityActionsHandler.swift
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
import NewTabPage

final class CapturingRecentActivityActionsHandler: RecentActivityActionsHandling {
    func open(_ url: URL, target: LinkOpenTarget) async {
        openCalls.append(.init(url: url, target: target))
    }

    func addFavorite(_ url: URL) async {
        addFavoriteCalls.append(url)
    }

    func removeFavorite(_ url: URL) async {
        removeFavoriteCalls.append(url)
    }

    func confirmBurn(_ url: URL) async -> Bool {
        confirmBurnCalls.append(url)
        return _confirmBurn(url)
    }

    let burnDidCompletePublisher: AnyPublisher<Void, Never> = Empty<Void, Never>().eraseToAnyPublisher()

    struct Open: Equatable {
        let url: URL
        let target: LinkOpenTarget
    }

    // swiftlint:disable:next identifier_name
    var _confirmBurn: (URL) -> Bool = { _ in true }

    var openCalls: [Open] = []
    var addFavoriteCalls: [URL] = []
    var removeFavoriteCalls: [URL] = []
    var confirmBurnCalls: [URL] = []
}
