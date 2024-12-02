//
//  ContinueSetUpModelTests.swift
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
import BrowserServicesKit
import Common
@testable import DuckDuckGo_Privacy_Browser

final class ContinueSetUpModelTests: XCTestCase {

    var vm: HomePage.Models.ContinueSetUpModel!
    var capturingDefaultBrowserProvider: CapturingDefaultBrowserProvider!
    var capturingDataImportProvider: CapturingDataImportProvider!
    var tabCollectionVM: TabCollectionViewModel!
    var emailManager: EmailManager!
    var emailStorage: MockEmailStorage!
    var duckPlayerPreferences: DuckPlayerPreferencesPersistor!
    var coookiePopupProtectionPreferences: MockCookiePopupProtectionPreferencesPersistor!
    var privacyConfigManager: MockPrivacyConfigurationManager!
    var dockCustomizer: DockCustomization!
    let userDefaults = UserDefaults(suiteName: "\(Bundle.main.bundleIdentifier!).\(NSApplication.runType)")!

    @MainActor override func setUp() {
        UserDefaultsWrapper<Any>.clearAll()
        userDefaults.set(Date(), forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        capturingDefaultBrowserProvider = CapturingDefaultBrowserProvider()
        capturingDataImportProvider = CapturingDataImportProvider()
        tabCollectionVM = TabCollectionViewModel()
        emailStorage = MockEmailStorage()
        emailManager = EmailManager(storage: emailStorage)
        duckPlayerPreferences = DuckPlayerPreferencesPersistorMock()
        privacyConfigManager = MockPrivacyConfigurationManager()
        let config = MockPrivacyConfiguration()
        privacyConfigManager.privacyConfig = config
        dockCustomizer = DockCustomizerMock()

        vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: capturingDefaultBrowserProvider,
            dockCustomizer: dockCustomizer,
            dataImportProvider: capturingDataImportProvider,
            tabOpener: TabCollectionViewModelTabOpener(tabCollectionViewModel: tabCollectionVM),
            emailManager: emailManager,
            duckPlayerPreferences: duckPlayerPreferences,
            privacyConfigurationManager: privacyConfigManager
        )
    }

    override func tearDown() {
        UserDefaultsWrapper<Any>.clearAll()
        capturingDefaultBrowserProvider = nil
        capturingDataImportProvider = nil
        tabCollectionVM = nil
        emailManager = nil
        emailStorage = nil
        vm = nil
    }

    func testModelReturnsCorrectStrings() {
        XCTAssertEqual(vm.itemsPerRow, HomePage.featuresPerRow)
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

        vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: capturingDefaultBrowserProvider,
            dockCustomizer: dockCustomizer,
            dataImportProvider: capturingDataImportProvider,
            tabOpener: TabCollectionViewModelTabOpener(tabCollectionViewModel: tabCollectionVM),
            emailManager: emailManager,
            duckPlayerPreferences: duckPlayerPreferences
        )

        XCTAssertFalse(vm.isMoreOrLessButtonNeeded)
    }

    @MainActor func testWhenInitializedForTheFirstTimeTheMatrixHasAllElementsInTheRightOrder() {
        let homePageIsFirstSession = UserDefaultsWrapper<Bool>(key: .homePageIsFirstSession, defaultValue: true)
        homePageIsFirstSession.wrappedValue = true
        var expectedMatrix = [[HomePage.Models.FeatureType.duckplayer, .emailProtection]]
        vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: capturingDefaultBrowserProvider,
            dockCustomizer: dockCustomizer,
            dataImportProvider: capturingDataImportProvider,
            tabOpener: TabCollectionViewModelTabOpener(tabCollectionViewModel: tabCollectionVM),
            emailManager: emailManager,
            duckPlayerPreferences: duckPlayerPreferences
        )

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.shouldShowAllFeatures = true

        expectedMatrix = expectedFeatureMatrixWithout(types: [])

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)
    }

    @MainActor func testWhenInitializedNotForTheFirstTimeTheMatrixHasAllElementsInTheRightOrder() {
        let homePageIsFirstSession = UserDefaultsWrapper<Bool>(key: .homePageIsFirstSession, defaultValue: true)
        homePageIsFirstSession.wrappedValue = false
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)
        vm.shouldShowAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix[0][0], HomePage.Models.FeatureType.defaultBrowser)
        XCTAssertEqual(vm.visibleFeaturesMatrix.reduce([], +).count, HomePage.Models.FeatureType.allCases.count)
    }

    func testWhenTogglingShowAllFeatureThenCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(types: [])

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= vm.itemsPerRow)
    }

    @MainActor func testWhenAskedToPerformActionForDefaultBrowserCardThenItPresentsTheDefaultBrowserPrompt() {
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

    @MainActor func testWhenIsDefaultBrowserAndTogglingShowAllFeatureThenCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.defaultBrowser])

        capturingDefaultBrowserProvider.isDefault = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(defaultBrowserProvider: capturingDefaultBrowserProvider, appGroupUserDefaults: userDefaults)

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

    @MainActor func testWhenUserHasUsedImportAndTogglingShowAllFeatureThenCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.importBookmarksAndPasswords])

        capturingDataImportProvider.didImport = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(dataImportProvider: capturingDataImportProvider, appGroupUserDefaults: userDefaults)

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

    @MainActor func testWhenUserHasEmailProtectionEnabledThenCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.emailProtection])

        emailStorage.isEmailProtectionEnabled = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(emailManager: emailManager, appGroupUserDefaults: userDefaults)

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

    @MainActor func testWhenUserHasDuckPlayerEnabledAndOverlayButtonNotPressedThenCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.duckplayer])

        duckPlayerPreferences.youtubeOverlayAnyButtonPressed = false
        duckPlayerPreferences.duckPlayerModeBool = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(duckPlayerPreferences: duckPlayerPreferences, appGroupUserDefaults: userDefaults)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= vm.itemsPerRow)
    }

    @MainActor func testWhenUserHasDuckPlayerDisabledAndOverlayButtonNotPressedThenCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.duckplayer])

        duckPlayerPreferences.youtubeOverlayAnyButtonPressed = false
        duckPlayerPreferences.duckPlayerModeBool = false
        vm = HomePage.Models.ContinueSetUpModel.fixture(duckPlayerPreferences: duckPlayerPreferences, appGroupUserDefaults: userDefaults)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= vm.itemsPerRow)
    }

    @MainActor func testWhenUserHasDuckPlayerOnAlwaysAskAndOverlayButtonNotPressedThenCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(types: [])

        duckPlayerPreferences.youtubeOverlayAnyButtonPressed = false
        duckPlayerPreferences.duckPlayerModeBool = nil
        vm = HomePage.Models.ContinueSetUpModel.fixture(duckPlayerPreferences: duckPlayerPreferences, appGroupUserDefaults: userDefaults)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= vm.itemsPerRow)
    }

    @MainActor func testWhenUserHasDuckPlayerOnAlwaysAskAndOverlayButtonIsPressedThenCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.duckplayer])

        duckPlayerPreferences.youtubeOverlayAnyButtonPressed = true
        duckPlayerPreferences.duckPlayerModeBool = nil
        vm = HomePage.Models.ContinueSetUpModel.fixture(duckPlayerPreferences: duckPlayerPreferences, appGroupUserDefaults: userDefaults)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
    }

    @MainActor func testThatWhenAllFeatureInactiveThenVisibleMatrixIsEmpty() {
        capturingDefaultBrowserProvider.isDefault = true
        emailStorage.isEmailProtectionEnabled = true
        duckPlayerPreferences.youtubeOverlayAnyButtonPressed = true
        capturingDataImportProvider.didImport = true
        dockCustomizer.addToDock()

        vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: capturingDefaultBrowserProvider,
            dockCustomizer: dockCustomizer,
            dataImportProvider: capturingDataImportProvider,
            tabOpener: TabCollectionViewModelTabOpener(tabCollectionViewModel: tabCollectionVM),
            emailManager: emailManager,
            duckPlayerPreferences: duckPlayerPreferences
        )

        XCTAssertEqual(vm.visibleFeaturesMatrix, [[]])
    }

    @MainActor func testDismissedItemsAreRemovedFromVisibleMatrixAndChoicesArePersisted() {
        let homePageIsFirstSession = UserDefaultsWrapper<Bool>(key: .homePageIsFirstSession, defaultValue: true)
        homePageIsFirstSession.wrappedValue = true
        vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: capturingDefaultBrowserProvider,
            dockCustomizer: dockCustomizer,
            dataImportProvider: capturingDataImportProvider,
            tabOpener: TabCollectionViewModelTabOpener(tabCollectionViewModel: tabCollectionVM),
            emailManager: emailManager,
            duckPlayerPreferences: duckPlayerPreferences
        )
        vm.shouldShowAllFeatures = true
        let expectedMatrix = expectedFeatureMatrixWithout(types: [])
        XCTAssertEqual(expectedMatrix, vm.visibleFeaturesMatrix)

        vm.removeItem(for: .defaultBrowser)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.defaultBrowser))

        vm.removeItem(for: .importBookmarksAndPasswords)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.importBookmarksAndPasswords))

        vm.removeItem(for: .duckplayer)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.duckplayer))

        vm.removeItem(for: .emailProtection)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.emailProtection))

#if !APPSTORE
        vm.removeItem(for: .dock)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.dock))
#endif

        let vm2 = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)
        XCTAssertTrue(vm2.visibleFeaturesMatrix.flatMap { $0 }.isEmpty)
    }

    @MainActor func testShowAllFeatureUserPreferencesIsPersisted() {
        let vm2 = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)
        vm2.shouldShowAllFeatures = true
        vm.shouldShowAllFeatures = false

        XCTAssertFalse(vm2.shouldShowAllFeatures)
    }

    private func doTheyContainTheSameElements(matrix1: [[HomePage.Models.FeatureType]], matrix2: [[HomePage.Models.FeatureType]]) -> Bool {
        Set(matrix1.flatMap { $0 }) == Set(matrix2.flatMap { $0 })
    }
    private func expectedFeatureMatrixWithout(types: [HomePage.Models.FeatureType]) -> [[HomePage.Models.FeatureType]] {
        var features = HomePage.Models.FeatureType.allCases
        var indexesToRemove: [Int] = []
        for type in types {
            indexesToRemove.append(features.firstIndex(of: type)!)
        }
        indexesToRemove.sort()
        indexesToRemove.reverse()
        for index in indexesToRemove {
            features.remove(at: index)
        }
        return features.chunked(into: HomePage.featuresPerRow)
    }

    @MainActor func test_WhenUserDoesntHaveApplicationInTheDock_ThenAddToDockCardIsDisplayed() {
#if !APPSTORE
        let dockCustomizer = DockCustomizerMock()

        let vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults, dockCustomizer: dockCustomizer)
        vm.shouldShowAllFeatures = true

        XCTAssert(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.dock))
#endif
    }

    @MainActor func test_WhenUserHasApplicationInTheDock_ThenAddToDockCardIsNotDisplayed() {
        let dockCustomizer = DockCustomizerMock()
        dockCustomizer.addToDock()

        let vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults, dockCustomizer: dockCustomizer)
        vm.shouldShowAllFeatures = true

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.dock))
    }

}

extension HomePage.Models.ContinueSetUpModel {
    @MainActor static func fixture(
        defaultBrowserProvider: DefaultBrowserProvider = CapturingDefaultBrowserProvider(),
        dataImportProvider: DataImportStatusProviding = CapturingDataImportProvider(),
        emailManager: EmailManager = EmailManager(storage: MockEmailStorage()),
        duckPlayerPreferences: DuckPlayerPreferencesPersistor = DuckPlayerPreferencesPersistorMock(),
        privacyConfig: MockPrivacyConfiguration = MockPrivacyConfiguration(),
        appGroupUserDefaults: UserDefaults,
        dockCustomizer: DockCustomization = DockCustomizerMock()
    ) -> HomePage.Models.ContinueSetUpModel {
        privacyConfig.featureSettings = [
            "networkProtection": "disabled"
        ] as! [String: String]
        let manager = MockPrivacyConfigurationManager()
        manager.privacyConfig = privacyConfig

        return HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: defaultBrowserProvider,
            dockCustomizer: dockCustomizer,
            dataImportProvider: dataImportProvider,
            tabOpener: TabCollectionViewModelTabOpener(tabCollectionViewModel: TabCollectionViewModel()),
            emailManager: emailManager,
            duckPlayerPreferences: duckPlayerPreferences,
            privacyConfigurationManager: manager)
    }
}
