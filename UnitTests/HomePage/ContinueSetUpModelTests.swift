//
//  SetUpModelTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser
import BrowserServicesKit

final class ContinueSetUpModelTests: XCTestCase {

    var vm: HomePage.Models.ContinueSetUpModel!
    var capturingDefaultBrowserProvider: CapturingDefaultBrowserProvider!
    var capturingDataImportProvider: CapturingDataImportProvider!
    var tabCollectionVM: TabCollectionViewModel!
    var emailManager: EmailManager!
    var emailStorage: MockEmailStorage!
    var privacyPreferences: PrivacySecurityPreferences!
    var duckPlayerPreferences: DuckPlayerPreferencesPersistor!
    var delegate: CapturingSetUpVewModelDelegate!

    override func setUp() {
        UserDefaultsWrapper<Any>.clearAll()
        capturingDefaultBrowserProvider = CapturingDefaultBrowserProvider()
        capturingDataImportProvider = CapturingDataImportProvider()
        tabCollectionVM = TabCollectionViewModel()
        emailStorage = MockEmailStorage()
        emailManager = EmailManager(storage: emailStorage)
        privacyPreferences = PrivacySecurityPreferences.shared
        duckPlayerPreferences = DuckPlayerPreferencesPersistorMock()
        delegate = CapturingSetUpVewModelDelegate()
        vm = HomePage.Models.ContinueSetUpModel(defaultBrowserProvider: capturingDefaultBrowserProvider, dataImportProvider: capturingDataImportProvider, tabCollectionViewModel: tabCollectionVM, emailManager: emailManager, privacyPreferences: privacyPreferences, duckPlayerPreferences: duckPlayerPreferences)
        vm.delegate = delegate
    }

    override func tearDown() {
        capturingDefaultBrowserProvider = nil
        capturingDataImportProvider = nil
        tabCollectionVM = nil
        emailManager = nil
        emailStorage = nil
        privacyPreferences = nil
        vm = nil
    }

    func testModelReturnsCorrectStrings() {
        XCTAssertEqual(vm.title, UserText.newTabSetUpSectionTitle)
        XCTAssertEqual(vm.deleteActionTitle, UserText.newTabSetUpRemoveItemAction)
        XCTAssertEqual(vm.actionTitle(for: .defaultBrowser), UserText.newTabSetUpDefaultBrowserAction)
        XCTAssertEqual(vm.actionTitle(for: .importBookmarksAndPasswords), UserText.newTabSetUpImportAction)
        XCTAssertEqual(vm.actionTitle(for: .duckplayer), UserText.newTabSetUpDuckPlayerAction)
        XCTAssertEqual(vm.actionTitle(for: .emailProtection), UserText.newTabSetUpEmailProtectionAction)
        XCTAssertEqual(vm.actionTitle(for: .coockiePopUp), UserText.newTabSetUpCoockeManagerAction)
    }

    func testModelReturnsCorrectDimensions() {
        XCTAssertEqual(vm.itemWidth, HomePage.Models.FeaturesGridDimensions.itemWidth)
        XCTAssertEqual(vm.itemHeight, HomePage.Models.FeaturesGridDimensions.itemHeight)
        XCTAssertEqual(vm.horizontalSpacing, HomePage.Models.FeaturesGridDimensions.horizontalSpacing)
        XCTAssertEqual(vm.verticalSpacing, HomePage.Models.FeaturesGridDimensions.verticalSpacing)
        XCTAssertEqual(vm.gridWidth, HomePage.Models.FeaturesGridDimensions.width)
        XCTAssertEqual(vm.itemsPerRow, HomePage.featuresPerRow)
    }

    func testIsMoreOrLessButtonNeededReturnTheExpectedValue() {
        XCTAssertTrue(vm.isMorOrLessButtonNeeded)

        capturingDefaultBrowserProvider.isDefault = true
        capturingDataImportProvider.hasUserUsedImport = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(defaultBrowserProvider: capturingDefaultBrowserProvider, dataImportProvider: capturingDataImportProvider)

        XCTAssertFalse(vm.isMorOrLessButtonNeeded)
    }

    func testWhenInitialisedTheMatrixHasOnlyThreeElementsInOneRow() {
        let expectedMatrix = HomePage.Models.FeatureType.allCases.chunked(into: HomePage.featuresPerRow)

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
        XCTAssertEqual(vm.visibleFeaturesMatrix, [expectedMatrix[0]])
    }

    func testWhenTogglingShowAllFeatureTheCorrectElementsAreVisible() {
        let expectedMatrix = HomePage.Models.FeatureType.allCases.chunked(into: HomePage.featuresPerRow)

        vm.shouldShowAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
        XCTAssertEqual(vm.visibleFeaturesMatrix, [expectedMatrix[0]])
    }

    func testWhenAskedToPerformActionFotDefaultBrowserCardThenItPresentsTheDefaultBrowserPrompt() {
        vm.performAction(for: .defaultBrowser)

        XCTAssertTrue(capturingDefaultBrowserProvider.presentDefaultBrowserPromptCalled)
        XCTAssertFalse(capturingDefaultBrowserProvider.openSystemPreferencesCalled)
    }

    func testWhenAskedToPerformActionForDefaultBrowserCardAndDefaultBrowserPromptThrowsThenItOpensSystemPreferences() {
        capturingDefaultBrowserProvider.throwError = true
        vm.performAction(for: .defaultBrowser)

        XCTAssertTrue(capturingDefaultBrowserProvider.presentDefaultBrowserPromptCalled)
        XCTAssertTrue(capturingDefaultBrowserProvider.openSystemPreferencesCalled)
    }

    func testWhenIsDefaultBrowserAndTogglingShowAllFeatureTheCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(type: .defaultBrowser)

        capturingDefaultBrowserProvider.isDefault = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(defaultBrowserProvider: capturingDefaultBrowserProvider)

        vm.shouldShowAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
        XCTAssertEqual(vm.visibleFeaturesMatrix, [expectedMatrix[0]])
    }

    func testWhenAskedToPerformActionForImportPromptThrowsThenItOpensImportWindow() {
        let numberOfFeatures = HomePage.Models.FeatureType.allCases.count
        vm.shouldShowAllFeatures = true
        XCTAssertEqual(vm.visibleFeaturesMatrix.flatMap { $0 }.count, numberOfFeatures)

        capturingDataImportProvider.hasUserUsedImport = true
        vm.performAction(for: .importBookmarksAndPasswords)

        XCTAssertTrue(capturingDataImportProvider.showImportWindowCalled)
        XCTAssertEqual(vm.visibleFeaturesMatrix.flatMap { $0 }.count, numberOfFeatures - 1)
    }

    func testWhenUserHasUsedImportAndTogglingShowAllFeatureTheCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(type: .importBookmarksAndPasswords)

        capturingDataImportProvider.hasUserUsedImport = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(dataImportProvider: capturingDataImportProvider)

        vm.shouldShowAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
        XCTAssertEqual(vm.visibleFeaturesMatrix, [expectedMatrix[0]])
    }

    func testWhenAskedToPerformActionForEmailProtectionThenItOpensEmailProtectionSite() {
        vm.performAction(for: .emailProtection)

        XCTAssertEqual(tabCollectionVM.tabs[1].url, EmailUrls().emailProtectionLink)
    }

    func testWhenUserHasEmailProtectionEnabledTheCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(type: .emailProtection)

        emailStorage.isEmailProtectionEnabled = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(emailManager: emailManager)

        vm.shouldShowAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
        XCTAssertEqual(vm.visibleFeaturesMatrix, [expectedMatrix[0]])
    }

    func testWhenAskedToPerformActionForCookieConsentThenShowsCookiePopUp() {
        let numberOfFeatures = HomePage.Models.FeatureType.allCases.count
        vm.shouldShowAllFeatures = true
        XCTAssertEqual(vm.visibleFeaturesMatrix.flatMap { $0 }.count, numberOfFeatures)

        vm.performAction(for: .coockiePopUp)

        XCTAssertTrue(delegate.showCookieConsentPopUpCalled)
        XCTAssertEqual(vm.visibleFeaturesMatrix.flatMap { $0 }.count, numberOfFeatures - 1)
    }

    func testWhenUserHasCookieConsnetEnabledTheCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(type: .coockiePopUp)

        privacyPreferences.autoconsentEnabled = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(privacyPreferences: privacyPreferences)

        vm.shouldShowAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
        XCTAssertEqual(vm.visibleFeaturesMatrix, [expectedMatrix[0]])
    }

    func testWhenAskedToPerformActionForDuckPlayerThenItOpensYoutubeVideo() {
        vm.performAction(for: .duckplayer)

        XCTAssertEqual(tabCollectionVM.tabs[1].url, vm.duckPlayerURL)
    }

    func testWhenUserHasDuckPlayerEnabledAndOverlayButtonNotPressedTheCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(type: .duckplayer)

        duckPlayerPreferences.youtubeOverlayUserPressedButtons = false
        duckPlayerPreferences.duckPlayerModeBool = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(duckPlayerPreferences: duckPlayerPreferences)

        vm.shouldShowAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
        XCTAssertEqual(vm.visibleFeaturesMatrix, [expectedMatrix[0]])
    }

    func testWhenUserHasDuckPlayerDisabledAndOverlayButtonNotPressedTheCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(type: .duckplayer)

        duckPlayerPreferences.youtubeOverlayUserPressedButtons = false
        duckPlayerPreferences.duckPlayerModeBool = false
        vm = HomePage.Models.ContinueSetUpModel.fixture(duckPlayerPreferences: duckPlayerPreferences)

        vm.shouldShowAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
        XCTAssertEqual(vm.visibleFeaturesMatrix, [expectedMatrix[0]])
    }

    func testWhenUserHasDuckPlayerOnAlwaysAskAndOverlayButtonNotPressedTheCorrectElementsAreVisible() {
        let expectedMatrix = HomePage.Models.FeatureType.allCases.chunked(into: HomePage.featuresPerRow)

        duckPlayerPreferences.youtubeOverlayUserPressedButtons = false
        duckPlayerPreferences.duckPlayerModeBool = nil
        vm = HomePage.Models.ContinueSetUpModel.fixture(duckPlayerPreferences: duckPlayerPreferences)

        vm.shouldShowAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
        XCTAssertEqual(vm.visibleFeaturesMatrix, [expectedMatrix[0]])
    }

    func testWhenUserHasDuckPlayerOnAlwaysAskAndOverlayButtonIsPressedTheCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(type: .duckplayer)

        duckPlayerPreferences.youtubeOverlayUserPressedButtons = true
        duckPlayerPreferences.duckPlayerModeBool = nil
        vm = HomePage.Models.ContinueSetUpModel.fixture(duckPlayerPreferences: duckPlayerPreferences)

        vm.shouldShowAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
        XCTAssertEqual(vm.visibleFeaturesMatrix, [expectedMatrix[0]])
    }

    func testThtatWhenIfAllFeatureActiveThenVisibleMatrixIsEmpty() {
        capturingDefaultBrowserProvider.isDefault = true
        emailStorage.isEmailProtectionEnabled = true
        privacyPreferences.autoconsentEnabled = true
        duckPlayerPreferences.youtubeOverlayUserPressedButtons = true
        capturingDataImportProvider.hasUserUsedImport = true
        vm = HomePage.Models.ContinueSetUpModel(defaultBrowserProvider: capturingDefaultBrowserProvider, dataImportProvider: capturingDataImportProvider, tabCollectionViewModel: tabCollectionVM, privacyPreferences: privacyPreferences, duckPlayerPreferences: duckPlayerPreferences)

        XCTAssertEqual(vm.visibleFeaturesMatrix, [[]])
    }

    private func expectedFeatureMatrixWithout(type: HomePage.Models.FeatureType) -> [[HomePage.Models.FeatureType]] {
        var features = HomePage.Models.FeatureType.allCases
        let indexToRemove = features.firstIndex(of: type)!
        features.remove(at: indexToRemove)
        return features.chunked(into: HomePage.featuresPerRow)
    }
}

extension HomePage.Models.ContinueSetUpModel {
    static func fixture(defaultBrowserProvider: DefaultBrowserProvider = CapturingDefaultBrowserProvider(), dataImportProvider: DataImportProvider = CapturingDataImportProvider(), tabCollectionViewModel: TabCollectionViewModel = TabCollectionViewModel(), emailManager: EmailManager = EmailManager(), privacyPreferences: PrivacySecurityPreferences = PrivacySecurityPreferences.shared, duckPlayerPreferences: DuckPlayerPreferencesPersistor = DuckPlayerPreferencesPersistorMock()) -> HomePage.Models.ContinueSetUpModel {
        HomePage.Models.ContinueSetUpModel(defaultBrowserProvider: defaultBrowserProvider, dataImportProvider: dataImportProvider, tabCollectionViewModel: tabCollectionViewModel, emailManager: emailManager, privacyPreferences: privacyPreferences, duckPlayerPreferences: duckPlayerPreferences)
    }
}
