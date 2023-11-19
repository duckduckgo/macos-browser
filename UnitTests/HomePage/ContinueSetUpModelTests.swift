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
import BrowserServicesKit
@testable import DuckDuckGo_Privacy_Browser

#if NETWORK_PROTECTION

final class MockNetworkProtectionRemoteMessaging: NetworkProtectionRemoteMessaging {

    var messages: [NetworkProtectionRemoteMessage] = []

    func fetchRemoteMessages(completion fetchCompletion: (() -> Void)? = nil) {
        fetchCompletion?()
    }

    func presentableRemoteMessages() -> [NetworkProtectionRemoteMessage] {
        messages
    }

    func dismiss(message: NetworkProtectionRemoteMessage) {}

}

#endif

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
    var privacyConfigManager: MockPrivacyConfigurationManager!
    let userDefaults: UserDefaults = UserDefaults(suiteName: "\(Bundle.main.bundleIdentifier!).\(NSApplication.runType)")!

    @MainActor override func setUp() {
        UserDefaultsWrapper<Any>.clearAll()
        userDefaults.set(Date(), forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(false, forKey: UserDefaultsWrapper<Date>.Key.homePageUserInteractedWithSurveyDay0.rawValue)
        userDefaults.set(false, forKey: UserDefaultsWrapper<Date>.Key.shouldShowNetworkProtectionSystemExtensionUpgradePrompt.rawValue)
        capturingDefaultBrowserProvider = CapturingDefaultBrowserProvider()
        capturingDataImportProvider = CapturingDataImportProvider()
        tabCollectionVM = TabCollectionViewModel()
        emailStorage = MockEmailStorage()
        emailManager = EmailManager(storage: emailStorage)
        privacyPreferences = PrivacySecurityPreferences.shared
        duckPlayerPreferences = DuckPlayerPreferencesPersistorMock()
        privacyConfigManager = MockPrivacyConfigurationManager()
        let config = MockPrivacyConfiguration()
        config.featureSettings = [
            "surveyCardDay0": "enabled",
            "surveyCardDay7": "enabled"
        ] as! [String: String]
        privacyConfigManager.privacyConfig = config

#if NETWORK_PROTECTION
        vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: capturingDefaultBrowserProvider,
            dataImportProvider: capturingDataImportProvider,
            tabCollectionViewModel: tabCollectionVM,
            emailManager: emailManager,
            privacyPreferences: privacyPreferences,
            duckPlayerPreferences: duckPlayerPreferences,
            networkProtectionRemoteMessaging: MockNetworkProtectionRemoteMessaging(),
            appGroupUserDefaults: userDefaults,
            privacyConfigurationManager: privacyConfigManager
        )
#else
        vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: capturingDefaultBrowserProvider,
            dataImportProvider: capturingDataImportProvider,
            tabCollectionViewModel: tabCollectionVM,
            emailManager: emailManager,
            privacyPreferences: privacyPreferences,
            duckPlayerPreferences: duckPlayerPreferences,
            privacyConfigurationManager: privacyConfigManager
        )
#endif

        delegate = CapturingSetUpVewModelDelegate()
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
        privacyPreferences.autoconsentEnabled = true

#if NETWORK_PROTECTION
        vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: capturingDefaultBrowserProvider,
            dataImportProvider: capturingDataImportProvider,
            tabCollectionViewModel: tabCollectionVM,
            emailManager: emailManager,
            privacyPreferences: privacyPreferences,
            duckPlayerPreferences: duckPlayerPreferences,
            networkProtectionRemoteMessaging: MockNetworkProtectionRemoteMessaging(),
            appGroupUserDefaults: userDefaults
        )
#else
        vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: capturingDefaultBrowserProvider,
            dataImportProvider: capturingDataImportProvider,
            tabCollectionViewModel: tabCollectionVM,
            emailManager: emailManager,
            privacyPreferences: privacyPreferences,
            duckPlayerPreferences: duckPlayerPreferences
        )
#endif

        XCTAssertFalse(vm.isMoreOrLessButtonNeeded)
    }

    func testWhenInitializedForTheFirstTimeTheMatrixHasAllElementsInTheRightOrder() {
        var expectedMatrix = [[HomePage.Models.FeatureType.duckplayer, HomePage.Models.FeatureType.cookiePopUp]]

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.shouldShowAllFeatures = true

        expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay7])

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)
    }

    @MainActor func testWhenInstallDateIsMoreThanADayAgoButLessThanAWeekAgoNoSurveyCardIsShown() {
        let aDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        userDefaults.set(aDayAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)
        vm.shouldShowAllFeatures = true

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay0))
        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay7))

        userDefaults.set(aDayAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay0))
        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay7))
    }

    @MainActor func testWhenInstallDateIsMoreThanAWeekAgoDay7SurveyCardIsShown() {
        let aDayAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        userDefaults.set(aDayAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)
        vm.shouldShowAllFeatures = true

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay0))
        XCTAssertTrue(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay7))
    }

    @MainActor func testWhenInstallDateIsMoreThanAWeekAgoAndUserInteractedWithDay0SurveyDay7SurveyCardIsNotShown() {
        let statisticStore = MockStatisticsStore()
        vm.statisticsStore = statisticStore
        vm.performAction(for: .surveyDay0)
        let aDayAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        userDefaults.set(aDayAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)
        vm.shouldShowAllFeatures = true

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay0))
        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay7))
    }

    @MainActor func testWhenInstallDateIsMoreThanAWeekAgoAndUserDismissedDay0SurveyDay7SurveyCardIsNotShown() {
        let statisticStore = MockStatisticsStore()
        vm.statisticsStore = statisticStore
        vm.removeItem(for: .surveyDay0)
        let aDayAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        userDefaults.set(aDayAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)
        vm.shouldShowAllFeatures = true

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay0))
        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay7))
    }

    @MainActor func testWhenInitializedNotForTheFirstTimeTheMatrixHasAllElementsInTheRightOrder() {
        var homePageIsFirstSession = UserDefaultsWrapper<Bool>(key: .homePageIsFirstSession, defaultValue: true)
        homePageIsFirstSession.wrappedValue = false
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)
        vm.shouldShowAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix[0][0], HomePage.Models.FeatureType.defaultBrowser)
        // All cases minus two since it will show only one of the surveys and no NetP card
        XCTAssertEqual(vm.visibleFeaturesMatrix.reduce([], +).count, HomePage.Models.FeatureType.allCases.count - 1)
    }

    func testWhenTogglingShowAllFeatureThenCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay7])

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
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.defaultBrowser, .surveyDay7])

        capturingDefaultBrowserProvider.isDefault = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(defaultBrowserProvider: capturingDefaultBrowserProvider, appGroupUserDefaults: userDefaults)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= vm.itemsPerRow)
    }

    @MainActor func testWhenAskedToPerformActionForImportPromptThrowsThenItOpensImportWindow() {
        let numberOfFeatures = HomePage.Models.FeatureType.allCases.count - 1
        vm.shouldShowAllFeatures = true
        XCTAssertEqual(vm.visibleFeaturesMatrix.flatMap { $0 }.count, numberOfFeatures)

        capturingDataImportProvider.didImport = true
        vm.performAction(for: .importBookmarksAndPasswords)

        XCTAssertTrue(capturingDataImportProvider.showImportWindowCalled)
        XCTAssertEqual(vm.visibleFeaturesMatrix.flatMap { $0 }.count, numberOfFeatures - 1)
    }

    @MainActor func testWhenUserHasUsedImportAndTogglingShowAllFeatureThenCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay7, .importBookmarksAndPasswords])

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
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay7, .emailProtection])

        emailStorage.isEmailProtectionEnabled = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(emailManager: emailManager, appGroupUserDefaults: userDefaults)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= vm.itemsPerRow)
    }

    @MainActor func testWhenAskedToPerformActionForCookieConsentThenShowsCookiePopUp() {
        let numberOfFeatures = HomePage.Models.FeatureType.allCases.count - 1
        vm.shouldShowAllFeatures = true
        XCTAssertEqual(vm.visibleFeaturesMatrix.flatMap { $0 }.count, numberOfFeatures)

        vm.performAction(for: .cookiePopUp)

        XCTAssertTrue(delegate.showCookieConsentPopUpCalled)
        XCTAssertEqual(vm.visibleFeaturesMatrix.flatMap { $0 }.count, numberOfFeatures - 1)
    }

    @MainActor func testWhenUserHasCookieConsentEnabledThenCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay7, .cookiePopUp])

        privacyPreferences.autoconsentEnabled = true
        vm = HomePage.Models.ContinueSetUpModel.fixture(privacyPreferences: privacyPreferences, appGroupUserDefaults: userDefaults)

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
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay7, .duckplayer])

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
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay7, .duckplayer])

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
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay7])

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
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay7, .duckplayer])

        duckPlayerPreferences.youtubeOverlayAnyButtonPressed = true
        duckPlayerPreferences.duckPlayerModeBool = nil
        vm = HomePage.Models.ContinueSetUpModel.fixture(duckPlayerPreferences: duckPlayerPreferences, appGroupUserDefaults: userDefaults)

        vm.shouldShowAllFeatures = true

        XCTAssertTrue(doTheyContainTheSameElements(matrix1: vm.visibleFeaturesMatrix, matrix2: expectedMatrix))

        vm.shouldShowAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
    }

    @MainActor func testWhenAskedToPerformActionForSurveyDay1ShowsTheSurveySite() {
        let atb = "someAtb"
        let statisticStore = MockStatisticsStore()
        statisticStore.atb = atb
        vm.statisticsStore = statisticStore

        vm.performAction(for: .surveyDay0)
        XCTAssertEqual(tabCollectionVM.tabs[1].url, URL(string: vm.day0SurveyURL + "&atb=" + atb))
    }

    @MainActor func testWhenAskedToPerformActionForSurveyDay7ShowsTheSurveySite() {
        let atb = "someAtb"
        let statisticStore = MockStatisticsStore()
        statisticStore.atb = atb
        vm.statisticsStore = statisticStore

        vm.performAction(for: .surveyDay7)
        XCTAssertEqual(tabCollectionVM.tabs[1].url, URL(string: vm.day7SurveyURL + "&atb=" + atb))
    }

    @MainActor func testThatWhenIfAllFeatureActiveThenVisibleMatrixIsEmpty() {
        capturingDefaultBrowserProvider.isDefault = true
        emailStorage.isEmailProtectionEnabled = true
        privacyPreferences.autoconsentEnabled = true
        duckPlayerPreferences.youtubeOverlayAnyButtonPressed = true
        capturingDataImportProvider.didImport = true
        userDefaults.set(false, forKey: UserDefaultsWrapper<Date>.Key.homePageShowSurveyDay0.rawValue)
        userDefaults.set(false, forKey: UserDefaultsWrapper<Date>.Key.homePageShowSurveyDay7.rawValue)

#if NETWORK_PROTECTION
        vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: capturingDefaultBrowserProvider,
            dataImportProvider: capturingDataImportProvider,
            tabCollectionViewModel: tabCollectionVM,
            emailManager: emailManager,
            privacyPreferences: privacyPreferences,
            duckPlayerPreferences: duckPlayerPreferences,
            networkProtectionRemoteMessaging: MockNetworkProtectionRemoteMessaging(),
            appGroupUserDefaults: userDefaults
        )
#else
        vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: capturingDefaultBrowserProvider,
            dataImportProvider: capturingDataImportProvider,
            tabCollectionViewModel: tabCollectionVM,
            emailManager: emailManager,
            privacyPreferences: privacyPreferences,
            duckPlayerPreferences: duckPlayerPreferences
        )
#endif

        XCTAssertEqual(vm.visibleFeaturesMatrix, [[]])
    }

    @MainActor func testDismissedItemsAreRemovedFromVisibleMatrixAndChoicesArePersisted() {
        vm.shouldShowAllFeatures = true
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay7])
        XCTAssertEqual(expectedMatrix, vm.visibleFeaturesMatrix)

        vm.removeItem(for: .surveyDay0)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.surveyDay0))

        userDefaults.set(Calendar.current.date(byAdding: .month, value: -1, to: Date())!, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)

        vm.removeItem(for: .surveyDay7)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.surveyDay7))

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

    enum SurveyDay {
        case day0
        case day7
    }
}

extension HomePage.Models.ContinueSetUpModel {
    @MainActor static func fixture(
        defaultBrowserProvider: DefaultBrowserProvider = CapturingDefaultBrowserProvider(),
        dataImportProvider: DataImportStatusProviding = CapturingDataImportProvider(),
        emailManager: EmailManager = EmailManager(storage: MockEmailStorage()),
        privacyPreferences: PrivacySecurityPreferences = PrivacySecurityPreferences.shared,
        duckPlayerPreferences: DuckPlayerPreferencesPersistor = DuckPlayerPreferencesPersistorMock(),
        privacyConfig: MockPrivacyConfiguration = MockPrivacyConfiguration(),
        appGroupUserDefaults: UserDefaults
    ) -> HomePage.Models.ContinueSetUpModel {
        privacyConfig.featureSettings = [
            "surveyCardDay0": "enabled",
            "surveyCardDay7": "enabled",
            "networkProtection": "disabled"
        ] as! [String: String]
        let manager = MockPrivacyConfigurationManager()
        manager.privacyConfig = privacyConfig

#if NETWORK_PROTECTION
        return HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: defaultBrowserProvider,
            dataImportProvider: dataImportProvider,
            tabCollectionViewModel: TabCollectionViewModel(),
            emailManager: emailManager,
            privacyPreferences: privacyPreferences,
            duckPlayerPreferences: duckPlayerPreferences,
            networkProtectionRemoteMessaging: MockNetworkProtectionRemoteMessaging(),
            appGroupUserDefaults: appGroupUserDefaults,
            privacyConfigurationManager: manager)
#else
        return HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: defaultBrowserProvider,
            dataImportProvider: dataImportProvider,
            tabCollectionViewModel: TabCollectionViewModel(),
            emailManager: emailManager,
            privacyPreferences: privacyPreferences,
            duckPlayerPreferences: duckPlayerPreferences,
            privacyConfigurationManager: manager)
#endif
    }
}
