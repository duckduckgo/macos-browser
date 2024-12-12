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

    @Published var cards: [NewTabPageNextStepsCardsClient.CardID] = []
    var cardsPublisher: AnyPublisher<[NewTabPageNextStepsCardsClient.CardID], Never> {
        $cards.dropFirst().removeDuplicates().eraseToAnyPublisher()
    }

    func handleAction(for card: NewTabPageNextStepsCardsClient.CardID) {
        handleActionCalls.append(card)
    }

    func dismiss(_ card: NewTabPageNextStepsCardsClient.CardID) {
        dismissCalls.append(card)
    }

    func willDisplayCards(_ cards: [NewTabPageNextStepsCardsClient.CardID]) {
        willDisplayCardsCalls.append(cards)
        willDisplayCardsImpl?(cards)
    }

    var handleActionCalls: [NewTabPageNextStepsCardsClient.CardID] = []
    var dismissCalls: [NewTabPageNextStepsCardsClient.CardID] = []
    var willDisplayCardsCalls: [[NewTabPageNextStepsCardsClient.CardID]] = []
    var willDisplayCardsImpl: (([NewTabPageNextStepsCardsClient.CardID]) -> Void)?
}
