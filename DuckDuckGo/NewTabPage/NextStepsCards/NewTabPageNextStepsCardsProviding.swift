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
import UserScript
import PixelKit

protocol NewTabPageNextStepsCardsProviding: AnyObject {
    var isViewExpanded: Bool { get set }
    var isViewExpandedPublisher: AnyPublisher<Bool, Never> { get }

    var cards: [NewTabPageNextStepsCardsClient.CardID] { get }
    var cardsPublisher: AnyPublisher<[NewTabPageNextStepsCardsClient.CardID], Never> { get }

    @MainActor
    func handleAction(for card: NewTabPageNextStepsCardsClient.CardID)

    @MainActor
    func dismiss(_ card: NewTabPageNextStepsCardsClient.CardID)

    func willDisplayCards(_ cards: [NewTabPageNextStepsCardsClient.CardID])
}

extension HomePage.Models.ContinueSetUpModel: NewTabPageNextStepsCardsProviding {
    var isViewExpanded: Bool {
        get {
            shouldShowAllFeatures
        }
        set {
            shouldShowAllFeatures = newValue
        }
    }

    var isViewExpandedPublisher: AnyPublisher<Bool, Never> {
        shouldShowAllFeaturesPublisher.eraseToAnyPublisher()
    }

    var cards: [NewTabPageNextStepsCardsClient.CardID] {
        featuresMatrix.flatMap { $0.map(NewTabPageNextStepsCardsClient.CardID.init) }
    }

    var cardsPublisher: AnyPublisher<[NewTabPageNextStepsCardsClient.CardID], Never> {
        $featuresMatrix.dropFirst().removeDuplicates()
            .map { matrix in
                matrix.flatMap { $0.map(NewTabPageNextStepsCardsClient.CardID.init) }
            }
            .eraseToAnyPublisher()
    }

    @MainActor
    func handleAction(for card: NewTabPageNextStepsCardsClient.CardID) {
        performAction(for: .init(card))
    }

    @MainActor
    func dismiss(_ card: NewTabPageNextStepsCardsClient.CardID) {
        removeItem(for: .init(card))
    }

    func willDisplayCards(_ cards: [NewTabPageNextStepsCardsClient.CardID]) {
        guard cards.contains(.addAppToDockMac) else {
            return
        }
        PixelKit.fire(GeneralPixel.addToDockNewTabPageCardPresented,
                      frequency: .unique,
                      includeAppVersionParameter: false)
    }
}

extension HomePage.Models.FeatureType {
    init(_ card: NewTabPageNextStepsCardsClient.CardID) {
        switch card {
        case .bringStuff:
            self = .importBookmarksAndPasswords
        case .defaultApp:
            self = .defaultBrowser
        case .emailProtection:
            self = .emailProtection
        case .duckplayer:
            self = .duckplayer
        case .addAppToDockMac:
            self = .dock
        }
    }
}

extension NewTabPageNextStepsCardsClient.CardID {
    init(_ feature: HomePage.Models.FeatureType) {
        switch feature {
        case .duckplayer:
            self = .duckplayer
        case .emailProtection:
            self = .emailProtection
        case .defaultBrowser:
            self = .defaultApp
        case .dock:
            self = .addAppToDockMac
        case .importBookmarksAndPasswords:
            self = .bringStuff
        }
    }
}
