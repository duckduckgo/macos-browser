//
//  NewTabPageNextStepsCardsProviding.swift
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

import Common
import Combine
import PixelKit
import UserScript

public protocol NewTabPageNextStepsCardsProviding: AnyObject {
    var isViewExpanded: Bool { get set }
    var isViewExpandedPublisher: AnyPublisher<Bool, Never> { get }

    var cards: [NewTabPageDataModel.CardID] { get }
    var cardsPublisher: AnyPublisher<[NewTabPageDataModel.CardID], Never> { get }

    @MainActor
    func handleAction(for card: NewTabPageDataModel.CardID)

    @MainActor
    func dismiss(_ card: NewTabPageDataModel.CardID)

    @MainActor
    func willDisplayCards(_ cards: [NewTabPageDataModel.CardID])
}
