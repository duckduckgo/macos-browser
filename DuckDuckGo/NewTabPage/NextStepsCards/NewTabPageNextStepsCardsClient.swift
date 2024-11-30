//
//  NewTabPageNextStepsCardsClient.swift
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

import Bookmarks
import Common
import Combine
import UserScript

protocol NewTabPageNextStepsCardsProviding: AnyObject {
    var isViewExpanded: Bool { get set }
    var isViewExpandedPublisher: AnyPublisher<Bool, Never> { get }

    var cards: [NewTabPageNextStepsCardsClient.CardID] { get }
    var cardsPublisher: AnyPublisher<[NewTabPageNextStepsCardsClient.CardID], Never> { get }

    @MainActor
    func performAction(for card: NewTabPageNextStepsCardsClient.CardID)
    func dismiss(_ card: NewTabPageNextStepsCardsClient.CardID)
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
        $shouldShowAllFeatures.dropFirst().eraseToAnyPublisher()
    }

    var cards: [NewTabPageNextStepsCardsClient.CardID] {
        featuresMatrix.flatMap { $0.map(NewTabPageNextStepsCardsClient.CardID.init) }
    }

    var cardsPublisher: AnyPublisher<[NewTabPageNextStepsCardsClient.CardID], Never> {
        $featuresMatrix.dropFirst()
            .map { matrix in
                matrix.flatMap { $0.map(NewTabPageNextStepsCardsClient.CardID.init) }
            }
            .eraseToAnyPublisher()
    }

    @MainActor
    func performAction(for card: NewTabPageNextStepsCardsClient.CardID) {
        performAction(for: .init(card))
    }

    func dismiss(_ card: NewTabPageNextStepsCardsClient.CardID) {
        removeItem(for: .init(card))
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

final class NewTabPageNextStepsCardsClient: NewTabPageScriptClient {

    let model: NewTabPageNextStepsCardsProviding
    weak var userScriptsSource: NewTabPageUserScriptsSource?
    private var cancellables: Set<AnyCancellable> = []

    init(model: NewTabPageNextStepsCardsProviding) {
        self.model = model

        model.cardsPublisher
            .sink { [weak self] cardIDs in
                Task { @MainActor in
                    self?.notifyDataUpdated(cardIDs)
                }
            }
            .store(in: &cancellables)

        model.isViewExpandedPublisher
            .sink { [weak self] showAllCards in
                Task { @MainActor in
                    self?.notifyConfigUpdated(showAllCards)
                }
            }
            .store(in: &cancellables)
    }

    enum MessageName: String, CaseIterable {
        case action = "nextSteps_action"
        case dismiss = "nextSteps_dismiss"
        case getConfig = "nextSteps_getConfig"
        case getData = "nextSteps_getData"
        case onConfigUpdate = "nextSteps_onConfigUpdate"
        case onDataUpdate = "nextSteps_onDataUpdate"
        case setConfig = "nextSteps_setConfig"
    }

    func registerMessageHandlers(for userScript: any SubfeatureWithExternalMessageHandling) {
        userScript.registerMessageHandlers([
            MessageName.action.rawValue: { [weak self] in try await self?.action(params: $0, original: $1) },
            MessageName.dismiss.rawValue: { [weak self] in try await self?.dismiss(params: $0, original: $1) },
            MessageName.getConfig.rawValue: { [weak self] in try await self?.getConfig(params: $0, original: $1) },
            MessageName.getData.rawValue: { [weak self] in try await self?.getData(params: $0, original: $1) },
            MessageName.setConfig.rawValue: { [weak self] in try await self?.setConfig(params: $0, original: $1) }
        ])
    }

    func action(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let card: NewTabPageNextStepsCardsClient.Card = DecodableHelper.decode(from: params) else {
            return nil
        }
        await model.performAction(for: card.id)
        return nil
    }

    func dismiss(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let card: Card = DecodableHelper.decode(from: params) else {
            return nil
        }
        model.dismiss(card.id)
        return nil
    }

    func getConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let expansion: NewTabPageUserScript.WidgetConfig.Expansion = model.isViewExpanded ? .expanded : .collapsed
        return NewTabPageUserScript.WidgetConfig(animation: .auto, expansion: expansion)
    }

    @MainActor
    func setConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let config: NewTabPageUserScript.WidgetConfig = DecodableHelper.decode(from: params) else {
            return nil
        }
        model.isViewExpanded = config.expansion == .expanded
        return nil
    }

    @MainActor
    func getData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let cards = model.cards.map(Card.init(id:))
        return NextStepsData(content: cards.isEmpty ? nil : cards)
    }

    @MainActor
    func notifyDataUpdated(_ cardIDs: [CardID]) {
        let cards = cardIDs.map(Card.init(id:))
        let params = NextStepsData(content: cards.isEmpty ? nil : cards)
        pushMessage(named: MessageName.onDataUpdate.rawValue, params: params)
    }

    @MainActor
    private func notifyConfigUpdated(_ showAllCards: Bool) {
        let expansion: NewTabPageUserScript.WidgetConfig.Expansion = showAllCards ? .expanded : .collapsed
        let config = NewTabPageUserScript.WidgetConfig(animation: .auto, expansion: expansion)
        pushMessage(named: MessageName.onConfigUpdate.rawValue, params: config)
    }
}

extension NewTabPageNextStepsCardsClient {

    enum CardID: String, Codable {
        case bringStuff
        case defaultApp
        case emailProtection
        case duckplayer
        case addAppToDockMac

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

    struct Card: Codable {
        let id: CardID
    }

    struct NextStepsData: Codable {
        let content: [Card]?
    }
}
