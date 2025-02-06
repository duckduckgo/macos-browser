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

import Common
import Combine
import UserScriptActionsManager
import WebKit

public final class NewTabPageNextStepsCardsClient: NewTabPageUserScriptClient {

    let model: NewTabPageNextStepsCardsProviding
    let willDisplayCardsPublisher: AnyPublisher<[NewTabPageDataModel.CardID], Never>

    private let willDisplayCardsSubject = PassthroughSubject<[NewTabPageDataModel.CardID], Never>()
    private let getDataSubject = PassthroughSubject<[NewTabPageDataModel.CardID], Never>()
    private let getConfigSubject = PassthroughSubject<Bool, Never>()
    private let notifyDataUpdatedSubject = PassthroughSubject<[NewTabPageDataModel.CardID], Never>()
    private let notifyConfigUpdatedSubject = PassthroughSubject<Bool, Never>()
    private var cancellables: Set<AnyCancellable> = []

    public init(model: NewTabPageNextStepsCardsProviding) {
        self.model = model
        willDisplayCardsPublisher = willDisplayCardsSubject.eraseToAnyPublisher()
        super.init()
        connectWillDisplayCardsPublisher()

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

        willDisplayCardsPublisher
            .sink { cards in
                Task { @MainActor in
                    model.willDisplayCards(cards)
                }
            }
            .store(in: &cancellables)
    }

    private func connectWillDisplayCardsPublisher() {
        let initialCards = Publishers.CombineLatest(getDataSubject, getConfigSubject)
            .map { cards, isViewExpanded in
                isViewExpanded ? cards : Array(cards.prefix(2))
            }
            .share()

        let firstInitialCards = initialCards.first()

        // only notify about visible cards (i.e. if collapsed, only the first 2)
        let cardsOnDataUpdated = notifyDataUpdatedSubject
            .drop(untilOutputFrom: firstInitialCards)
            .map { [weak self] cards in
                self?.model.isViewExpanded == true ? cards: Array(cards.prefix(2))
            }

        // only notify about cards revealed by expanding the view (i.e. other than the first 2)
        let cardsOnConfigUpdated = notifyConfigUpdatedSubject
            .drop(untilOutputFrom: firstInitialCards)
            .compactMap { [weak self] isViewExpanded -> [NewTabPageDataModel.CardID]? in
                guard let self, isViewExpanded, model.cards.count > 2 else {
                    return nil
                }
                return Array(self.model.cards.suffix(from: 2))
            }

        Publishers.Merge3(initialCards, cardsOnDataUpdated, cardsOnConfigUpdated)
            .filter { !$0.isEmpty }
            .sink { [weak self] cards in
                self?.willDisplayCardsSubject.send(cards)
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

    public override func registerMessageHandlers(for userScript: NewTabPageUserScript) {
        userScript.registerMessageHandlers([
            MessageName.action.rawValue: { [weak self] in try await self?.action(params: $0, original: $1) },
            MessageName.dismiss.rawValue: { [weak self] in try await self?.dismiss(params: $0, original: $1) },
            MessageName.getConfig.rawValue: { [weak self] in try await self?.getConfig(params: $0, original: $1) },
            MessageName.getData.rawValue: { [weak self] in try await self?.getData(params: $0, original: $1) },
            MessageName.setConfig.rawValue: { [weak self] in try await self?.setConfig(params: $0, original: $1) }
        ])
    }

    @MainActor
    private func action(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let card: NewTabPageDataModel.Card = DecodableHelper.decode(from: params) else {
            return nil
        }
        model.handleAction(for: card.id)
        return nil
    }

    @MainActor
    private func dismiss(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let card: NewTabPageDataModel.Card = DecodableHelper.decode(from: params) else {
            return nil
        }
        model.dismiss(card.id)
        return nil
    }

    private func getConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let expansion: NewTabPageUserScript.WidgetConfig.Expansion = model.isViewExpanded ? .expanded : .collapsed

        getConfigSubject.send(model.isViewExpanded)
        return NewTabPageUserScript.WidgetConfig(animation: .noAnimation, expansion: expansion)
    }

    @MainActor
    private func setConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let config: NewTabPageUserScript.WidgetConfig = DecodableHelper.decode(from: params) else {
            return nil
        }
        model.isViewExpanded = config.expansion == .expanded
        return nil
    }

    @MainActor
    private func getData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let cardIDs = model.cards
        let cards = cardIDs.map(NewTabPageDataModel.Card.init(id:))

        getDataSubject.send(cardIDs)
        return NewTabPageDataModel.NextStepsData(content: cards.isEmpty ? nil : cards)
    }

    @MainActor
    private func notifyDataUpdated(_ cardIDs: [NewTabPageDataModel.CardID]) {
        let cards = cardIDs.map(NewTabPageDataModel.Card.init(id:))
        let params = NewTabPageDataModel.NextStepsData(content: cards.isEmpty ? nil : cards)

        notifyDataUpdatedSubject.send(cardIDs)
        pushMessage(named: MessageName.onDataUpdate.rawValue, params: params)
    }

    @MainActor
    private func notifyConfigUpdated(_ showAllCards: Bool) {
        let expansion: NewTabPageUserScript.WidgetConfig.Expansion = showAllCards ? .expanded : .collapsed
        let config = NewTabPageUserScript.WidgetConfig(animation: .noAnimation, expansion: expansion)

        notifyConfigUpdatedSubject.send(showAllCards)
        pushMessage(named: MessageName.onConfigUpdate.rawValue, params: config)
    }
}
