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

    @MainActor override func setUp() {
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
        UserDefaultsWrapper<Any>.clearAll()
        capturingDefaultBrowserProvider = nil
        capturingDataImportProvider = nil
        tabCollectionVM = nil
        emailManager = nil
        emailStorage = nil
        privacyPreferences = nil
        vm = nil
    }

    func testModelReturnsCorrectStrings() {
        XCTAssertEqual(vm.deleteActionTitle, UserText.newTabSetUpRemoveItemAction)
    }

    func testModelReturnsCorrectDimensions() {
        XCTAssertEqual(vm.itemWidth, HomePage.Models.FeaturesGridDimensions.itemWidth)
        XCTAssertEqual(vm.itemHeight, HomePage.Models.FeaturesGridDimensions.itemHeight)
        XCTAssertEqual(vm.horizontalSpacing, HomePage.Models.FeaturesGridDimensions.horizontalSpacing)
        XCTAssertEqual(vm.verticalSpacing, HomePage.Models.FeaturesGridDimensions.verticalSpacing)
        XCTAssertEqual(vm.gridWidth, HomePage.Models.FeaturesGridDimensions.width)
        XCTAssertEqual(vm.itemsPerRow, 2)
    }

    @MainActor func testIsMoreOrLessButtonNeededReturnTheExpectedValue() {
        XCTAssertTrue(vm.isMoreOrLessButtonNeeded)

        capturingDefaultBrowserProvider.isDefault = true
        capturingDataImportProvider.didImport = true
        duckPlayerPreferences.youtubeOverlayAnyButtonPressed = true
        privacyPreferences.autoconsentEnabled = true
        vm = HomePage.Models.ContinueSetUpModel(defaultBrowserProvider: capturingDefaultBrowserProvider, dataImportProvider: capturingDataImportProvider, tabCollectionViewModel: tabCollectionVM, emailManager: emailManager, privacyPreferences: privacyPreferences, duckPlayerPreferences: duckPlayerPreferences)
        print(vm.visibleFeaturesMatrix)
        XCTAssertFalse(vm.isMoreOrLessButtonNeeded)
    }

    func testWhenInitialisedForTheFirstTimeTheMatrixHasAllElementsInTheRightOrder() {
        var expectedMatrix = [[HomePage.Models.FeatureType.duckplayer, HomePage.Models.FeatureType.cookiePopUp]]

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.shouldShowAllFeatures = true

        expectedMatrix = HomePage.Models.FeatureType.allCases.chunked(into: vm.itemsPerRow)

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)
    }

    @MainActor func testWhenInitialisedNotForTheFirstTimeTheMatrixHasAllElementsInTheRightOrder() {
        var homePageIsFirstSession = UserDefaultsWrapper<Bool>(key: .homePageIsFirstSession, defaultValue: true)
        homePageIsFirstSession.wrappedValue = false
        vm = HomePage.Models.ContinueSetUpModel.fixture()
        vm.shouldShowAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix[0][0], HomePage.Models.FeatureType.defaultBrowser)
        XCTAssertEqual(vm.visibleFeaturesMatrix.reduce([], +).count, HomePage.Models.FeatureType.allCases.count)
    }

    func testWhenTogglingShowAllFeatureTheCorrectElementsAreVisible() {
        let expectedMatrix = HomePage.Models.FeatureType.allCases.chunked(into: vm.itemsPerRow)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= vm.itemsPerRow)
    }

    @MainActor func testWhenAskedToPerformActionFotDefaultBrowserCardThenItPresentsTheDefaultBrowserPrompt() {
        vm.performAction(for: .defaultBrowser)

        XCTAssertTrue(capturingDefaultBrowserProvider.presentDefaultBrowserPromptCalled)
        XCTAssertFalse(capturingDefaultBrowserProvider.openSystemPreferencesCalled)
    }

    @MainActor func testWhenAskedToPerformActionForDefaultBrowserCardAndDefaultBrowserPromptThrowsThenItOpensSystemPreferences() {
        capturingDefaultBrowserProvider.throwError = true
        vm.performAction(for: .defaultBrowser)

        XCTAssertTrue(capturingDefaultBrowserProvider.presentDefaultBrowserPromptCalled)
        XCTAssertTrue(capturingDefaultBrowserProvider.openSystemPreferencesCalled)
    }

    @MainActor func testWhenIsDefaultBrowserAndTogglingShowAllFeatureTheCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(type: .defaultBrowser)

        capturingDefaultBrowserProvider.isDefault = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(defaultBrowserProvider: capturingDefaultBrowserProvider)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= vm.itemsPerRow)
    }

    @MainActor func testWhenAskedToPerformActionForImportPromptThrowsThenItOpensImportWindow() {
        let numberOfFeatures = HomePage.Models.FeatureType.allCases.count
        vm.shouldShowAllFeatures = true
        XCTAssertEqual(vm.visibleFeaturesMatrix.flatMap { $0 }.count, numberOfFeatures)

        capturingDataImportProvider.didImport = true
        vm.performAction(for: .importBookmarksAndPasswords)

        XCTAssertTrue(capturingDataImportProvider.showImportWindowCalled)
        XCTAssertEqual(vm.visibleFeaturesMatrix.flatMap { $0 }.count, numberOfFeatures - 1)
    }

    @MainActor func testWhenUserHasUsedImportAndTogglingShowAllFeatureTheCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(type: .importBookmarksAndPasswords)

        capturingDataImportProvider.didImport = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(dataImportProvider: capturingDataImportProvider)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= vm.itemsPerRow)
    }

    @MainActor func testWhenAskedToPerformActionForEmailProtectionThenItOpensEmailProtectionSite() {
        vm.performAction(for: .emailProtection)

        XCTAssertEqual(tabCollectionVM.tabs[1].url, EmailUrls().emailProtectionLink)
    }

    @MainActor func testWhenUserHasEmailProtectionEnabledTheCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(type: .emailProtection)

        emailStorage.isEmailProtectionEnabled = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(emailManager: emailManager)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= vm.itemsPerRow)
    }

    @MainActor func testWhenAskedToPerformActionForCookieConsentThenShowsCookiePopUp() {
        let numberOfFeatures = HomePage.Models.FeatureType.allCases.count
        vm.shouldShowAllFeatures = true
        XCTAssertEqual(vm.visibleFeaturesMatrix.flatMap { $0 }.count, numberOfFeatures)

        vm.performAction(for: .cookiePopUp)

        XCTAssertTrue(delegate.showCookieConsentPopUpCalled)
        XCTAssertEqual(vm.visibleFeaturesMatrix.flatMap { $0 }.count, numberOfFeatures - 1)
    }

    @MainActor func testWhenUserHasCookieConsnetEnabledTheCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(type: .cookiePopUp)

        privacyPreferences.autoconsentEnabled = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(privacyPreferences: privacyPreferences)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= vm.itemsPerRow)
    }

    @MainActor func testWhenAskedToPerformActionForDuckPlayerThenItOpensYoutubeVideo() {
        vm.performAction(for: .duckplayer)

        XCTAssertEqual(tabCollectionVM.tabs[1].url, URL(string: vm.duckPlayerURL))
    }

    @MainActor func testWhenUserHasDuckPlayerEnabledAndOverlayButtonNotPressedTheCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(type: .duckplayer)

        duckPlayerPreferences.youtubeOverlayAnyButtonPressed = false
        duckPlayerPreferences.duckPlayerModeBool = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(duckPlayerPreferences: duckPlayerPreferences)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= vm.itemsPerRow)
    }

    @MainActor func testWhenUserHasDuckPlayerDisabledAndOverlayButtonNotPressedTheCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(type: .duckplayer)

        duckPlayerPreferences.youtubeOverlayAnyButtonPressed = false
        duckPlayerPreferences.duckPlayerModeBool = false
        vm = HomePage.Models.ContinueSetUpModel.fixture(duckPlayerPreferences: duckPlayerPreferences)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= vm.itemsPerRow)
    }

    @MainActor func testWhenUserHasDuckPlayerOnAlwaysAskAndOverlayButtonNotPressedTheCorrectElementsAreVisible() {
        let expectedMatrix = HomePage.Models.FeatureType.allCases.chunked(into: HomePage.featuresPerRow)

        duckPlayerPreferences.youtubeOverlayAnyButtonPressed = false
        duckPlayerPreferences.duckPlayerModeBool = nil
        vm = HomePage.Models.ContinueSetUpModel.fixture(duckPlayerPreferences: duckPlayerPreferences)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= vm.itemsPerRow)
    }

    @MainActor func testWhenUserHasDuckPlayerOnAlwaysAskAndOverlayButtonIsPressedTheCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(type: .duckplayer)

        duckPlayerPreferences.youtubeOverlayAnyButtonPressed = true
        duckPlayerPreferences.duckPlayerModeBool = nil
        vm = HomePage.Models.ContinueSetUpModel.fixture(duckPlayerPreferences: duckPlayerPreferences)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
    }

    func testThtatWhenIfAllFeatureActiveThenVisibleMatrixIsEmpty() {
        var homePageShowAddToDock = UserDefaultsWrapper<Bool>(key: .homePageShowAddToDock, defaultValue: true)
        homePageShowAddToDock.wrappedValue = false
        capturingDefaultBrowserProvider.isDefault = true
        emailStorage.isEmailProtectionEnabled = true
        privacyPreferences.autoconsentEnabled = true
        duckPlayerPreferences.youtubeOverlayAnyButtonPressed = true
        capturingDataImportProvider.didImport = true

        vm = HomePage.Models.ContinueSetUpModel(defaultBrowserProvider: capturingDefaultBrowserProvider, dataImportProvider: capturingDataImportProvider, tabCollectionViewModel: tabCollectionVM, emailManager: emailManager, privacyPreferences: privacyPreferences, duckPlayerPreferences: duckPlayerPreferences)

        XCTAssertEqual(vm.visibleFeaturesMatrix, [[]])
    }

    @MainActor func testDismissedItemsAreRemovedFromVisibleMatrixAndChoicesArePersisted() {
        vm.shouldShowAllFeatures = true
        XCTAssertEqual(HomePage.Models.FeatureType.allCases.chunked(into: vm.itemsPerRow), vm.visibleFeaturesMatrix)

        vm.removeItem(for: .defaultBrowser)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.defaultBrowser))

        vm.removeItem(for: .importBookmarksAndPasswords)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.importBookmarksAndPasswords))

        vm.removeItem(for: .duckplayer)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.duckplayer))

        vm.removeItem(for: .emailProtection)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.emailProtection))

        vm.removeItem(for: .cookiePopUp)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.cookiePopUp))

//#if !APPSTORE
//        vm.removeItem(for: .addToDock)
//        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.addToDock))
//#endif

        let vm2 = HomePage.Models.ContinueSetUpModel.fixture()
        XCTAssertTrue(vm2.visibleFeaturesMatrix.flatMap { $0 }.isEmpty)
    }

    @MainActor func testShowAllFeatureUserPreferencesIsPersisted() {
        let vm2 = HomePage.Models.ContinueSetUpModel.fixture()
        vm2.shouldShowAllFeatures = true
        vm.shouldShowAllFeatures = false

        XCTAssertFalse(vm2.shouldShowAllFeatures)
    }

    private func doTheyContainTheSameElements(matrix1: [[HomePage.Models.FeatureType]], matrix2: [[HomePage.Models.FeatureType]]) -> Bool {
        let features1 = matrix1.reduce([], +)
        let features2 = matrix2.reduce([], +)
        if features1.count != features2.count {
            return false
        }
        for feature in features1 where !features2.contains(feature) {
            return false
        }
        return true
    }
    private func expectedFeatureMatrixWithout(type: HomePage.Models.FeatureType) -> [[HomePage.Models.FeatureType]] {
        var features = HomePage.Models.FeatureType.allCases
        let indexToRemove = features.firstIndex(of: type)!
        features.remove(at: indexToRemove)
        return features.chunked(into: HomePage.featuresPerRow)
    }
}

extension HomePage.Models.ContinueSetUpModel {
    @MainActor static func fixture(defaultBrowserProvider: DefaultBrowserProvider = CapturingDefaultBrowserProvider(), dataImportProvider: DataImportStatusProviding = CapturingDataImportProvider(), emailManager: EmailManager = EmailManager(), privacyPreferences: PrivacySecurityPreferences = PrivacySecurityPreferences.shared, duckPlayerPreferences: DuckPlayerPreferencesPersistor = DuckPlayerPreferencesPersistorMock()) -> HomePage.Models.ContinueSetUpModel {
        HomePage.Models.ContinueSetUpModel(defaultBrowserProvider: defaultBrowserProvider, dataImportProvider: dataImportProvider, tabCollectionViewModel: TabCollectionViewModel(), emailManager: emailManager, privacyPreferences: privacyPreferences, duckPlayerPreferences: duckPlayerPreferences)
    }
}
