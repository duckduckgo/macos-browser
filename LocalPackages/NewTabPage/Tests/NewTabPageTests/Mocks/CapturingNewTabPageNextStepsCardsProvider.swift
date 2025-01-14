//
//  CapturingNewTabPageNextStepsCardsProvider.swift
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
import XCTest
@testable import NewTabPage

final class CapturingNewTabPageNextStepsCardsProvider: NewTabPageNextStepsCardsProviding {

    @Published var isViewExpanded: Bool = false
    var isViewExpandedPublisher: AnyPublisher<Bool, Never> {
        $isViewExpanded.dropFirst().removeDuplicates().eraseToAnyPublisher()
    }

    @Published var cards: [NewTabPageDataModel.CardID] = []
    var cardsPublisher: AnyPublisher<[NewTabPageDataModel.CardID], Never> {
        $cards.dropFirst().removeDuplicates().eraseToAnyPublisher()
    }

    func handleAction(for card: NewTabPageDataModel.CardID) {
        handleActionCalls.append(card)
    }

    func dismiss(_ card: NewTabPageDataModel.CardID) {
        dismissCalls.append(card)
    }

    func willDisplayCards(_ cards: [NewTabPageDataModel.CardID]) {
        willDisplayCardsCalls.append(cards)
        willDisplayCardsImpl?(cards)
    }

    var handleActionCalls: [NewTabPageDataModel.CardID] = []
    var dismissCalls: [NewTabPageDataModel.CardID] = []
    var willDisplayCardsCalls: [[NewTabPageDataModel.CardID]] = []
    var willDisplayCardsImpl: (([NewTabPageDataModel.CardID]) -> Void)?
}
