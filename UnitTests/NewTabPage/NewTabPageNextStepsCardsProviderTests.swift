//
//  NewTabPageNextStepsCardsProviderTests.swift
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

import BrowserServicesKit
import Combine
import NewTabPage
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class NewTabPageNextStepsCardsProviderTests: XCTestCase {
    var provider: NewTabPageNextStepsCardsProvider!

    @MainActor
    override func setUp() async throws {
        let privacyConfigManager = MockPrivacyConfigurationManager()
        let config = MockPrivacyConfiguration()
        privacyConfigManager.privacyConfig = config

        let continueSetUpModel = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: CapturingDefaultBrowserProvider(),
            dockCustomizer: DockCustomizerMock(),
            dataImportProvider: CapturingDataImportProvider(),
            tabOpener: TabCollectionViewModelTabOpener(tabCollectionViewModel: TabCollectionViewModel()),
            emailManager: EmailManager(storage: MockEmailStorage()),
            duckPlayerPreferences: DuckPlayerPreferencesPersistorMock(),
            privacyConfigurationManager: privacyConfigManager
        )

        provider = NewTabPageNextStepsCardsProvider(
            continueSetUpModel: continueSetUpModel,
            appearancePreferences: AppearancePreferences(persistor: MockAppearancePreferencesPersistor())
        )
    }

    func testWhenCardsViewIsNotOutdatedThenCardsAreReportedByModel() {
        provider.appearancePreferences.isContinueSetUpCardsViewOutdated = false
        provider.continueSetUpModel.featuresMatrix = [[.defaultBrowser, .dock, .emailProtection]]

        XCTAssertEqual(provider.cards, [.defaultApp, .addAppToDockMac, .emailProtection])
    }

    func testWhenCardsViewIsOutdatedThenCardsAreEmpty() {
        provider.appearancePreferences.isContinueSetUpCardsViewOutdated = true
        provider.continueSetUpModel.featuresMatrix = [[.defaultBrowser, .dock, .emailProtection]]

        XCTAssertEqual(provider.cards, [])
    }

    func testWhenCardsViewIsNotOutdatedThenCardsAreEmitted() {
        provider.appearancePreferences.isContinueSetUpCardsViewOutdated = false
        provider.continueSetUpModel.featuresMatrix = [[.defaultBrowser]]

        var cardsEvents = [[NewTabPageDataModel.CardID]]()

        let cancellable = provider.cardsPublisher
            .sink { cards in
                cardsEvents.append(cards)
            }

        provider.continueSetUpModel.featuresMatrix = [[.dock]]
        provider.continueSetUpModel.featuresMatrix = [[.dock, .duckplayer]]
        provider.continueSetUpModel.featuresMatrix = [[.defaultBrowser]]

        cancellable.cancel()
        XCTAssertEqual(cardsEvents, [[.addAppToDockMac], [.addAppToDockMac, .duckplayer], [.defaultApp]])
    }

    func testWhenCardsViewIsOutdatedThenEmptyCardsAreEmitted() {
        provider.appearancePreferences.isContinueSetUpCardsViewOutdated = true
        provider.continueSetUpModel.featuresMatrix = [[.defaultBrowser]]

        var cardsEvents = [[NewTabPageDataModel.CardID]]()

        let cancellable = provider.cardsPublisher
            .sink { cards in
                cardsEvents.append(cards)
            }

        provider.continueSetUpModel.featuresMatrix = [[.dock]]
        provider.continueSetUpModel.featuresMatrix = [[.duckplayer]]
        provider.continueSetUpModel.featuresMatrix = [[.defaultBrowser]]

        cancellable.cancel()
        XCTAssertEqual(cardsEvents, [[], [], []])
    }

    func testWhenCardsViewBecomesOutdatedThenCardsStopBeingEmitted() {
        provider.appearancePreferences.isContinueSetUpCardsViewOutdated = false
        provider.continueSetUpModel.featuresMatrix = [[.defaultBrowser]]

        var cardsEvents = [[NewTabPageDataModel.CardID]]()

        let cancellable = provider.cardsPublisher
            .sink { cards in
                cardsEvents.append(cards)
            }

        provider.continueSetUpModel.featuresMatrix = [[.dock]]
        provider.continueSetUpModel.featuresMatrix = [[.dock, .duckplayer]]
        provider.appearancePreferences.isContinueSetUpCardsViewOutdated = true
        provider.continueSetUpModel.featuresMatrix = [[.defaultBrowser]]

        cancellable.cancel()
        XCTAssertEqual(cardsEvents, [[.addAppToDockMac], [.addAppToDockMac, .duckplayer], [], []])
    }
}
