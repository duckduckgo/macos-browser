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

#if DBP

final class MockDataBrokerProtectionRemoteMessaging: DataBrokerProtectionRemoteMessaging {

    var messages: [DataBrokerProtectionRemoteMessage] = []

    func fetchRemoteMessages(completion fetchCompletion: (() -> Void)? = nil) {
        fetchCompletion?()
    }

    func presentableRemoteMessages() -> [DataBrokerProtectionRemoteMessage] {
        messages
    }

    func dismiss(message: DataBrokerProtectionRemoteMessage) {}

}

#endif

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
    var randomNumberGenerator: MockRandomNumberGenerator!
    let userDefaults = UserDefaults(suiteName: "\(Bundle.main.bundleIdentifier!).\(NSApplication.runType)")!

    @MainActor override func setUp() {
        UserDefaultsWrapper<Any>.clearAll()
        userDefaults.set(Date(), forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(false, forKey: UserDefaultsWrapper<Date>.Key.homePageUserInteractedWithSurveyDay0.rawValue)
        userDefaults.set(nil, forKey: UserDefaultsWrapper<Bool?>.Key.homePageShowSurveyDay0in10Percent.rawValue)
        userDefaults.set(nil, forKey: UserDefaultsWrapper<Bool?>.Key.homePageShowSurveyDay14in10Percent.rawValue)
        userDefaults.set(false, forKey: UserDefaultsWrapper<Bool>.Key.homePageUserInteractedWithSurveyDay0.rawValue)
        capturingDefaultBrowserProvider = CapturingDefaultBrowserProvider()
        capturingDataImportProvider = CapturingDataImportProvider()
        tabCollectionVM = TabCollectionViewModel()
        emailStorage = MockEmailStorage()
        emailManager = EmailManager(storage: emailStorage)
        duckPlayerPreferences = DuckPlayerPreferencesPersistorMock()
        privacyConfigManager = MockPrivacyConfigurationManager()
        let config = MockPrivacyConfiguration()
        config.featureSettings = [
            "surveyCardDay0": "enabled",
            "surveyCardDay14": "enabled"
        ] as! [String: String]
        privacyConfigManager.privacyConfig = config
        randomNumberGenerator = MockRandomNumberGenerator()

#if NETWORK_PROTECTION && DBP
        let messaging = HomePageRemoteMessaging(
            networkProtectionRemoteMessaging: MockNetworkProtectionRemoteMessaging(),
            networkProtectionUserDefaults: userDefaults,
            dataBrokerProtectionRemoteMessaging: MockDataBrokerProtectionRemoteMessaging(),
            dataBrokerProtectionUserDefaults: userDefaults
        )
#elseif NETWORK_PROTECTION
        let messaging = HomePageRemoteMessaging(
            networkProtectionRemoteMessaging: MockNetworkProtectionRemoteMessaging(),
            networkProtectionUserDefaults: userDefaults
        )
#elseif DBP
        let messaging =  HomePageRemoteMessaging(
            dataBrokerProtectionRemoteMessaging: MockDataBrokerProtectionRemoteMessaging(),
            dataBrokerProtectionUserDefaults: userDefaults
        )
#else
        let messaging =  HomePageRemoteMessaging.defaultMessaging()
#endif

        vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: capturingDefaultBrowserProvider,
            dataImportProvider: capturingDataImportProvider,
            tabCollectionViewModel: tabCollectionVM,
            emailManager: emailManager,
            duckPlayerPreferences: duckPlayerPreferences,
            homePageRemoteMessaging: messaging,
            privacyConfigurationManager: privacyConfigManager,
            randomNumberGenerator: randomNumberGenerator
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
            dataImportProvider: capturingDataImportProvider,
            tabCollectionViewModel: tabCollectionVM,
            emailManager: emailManager,
            duckPlayerPreferences: duckPlayerPreferences,
            homePageRemoteMessaging: createMessaging()
        )

        XCTAssertFalse(vm.isMoreOrLessButtonNeeded)
    }

    func testWhenInitializedForTheFirstTimeTheMatrixHasAllElementsInTheRightOrder() {
        var expectedMatrix = [[HomePage.Models.FeatureType.duckplayer, .emailProtection]]

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.shouldShowAllFeatures = true

        expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay14])

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)
    }

    @MainActor func testWhenInstallDateIsLessThanADayAgoThenRandomGeneratorIsRequestARandomNumberInTheCorrectRange() {
        XCTAssertEqual(randomNumberGenerator.capturedRange, 0..<100)
    }

    @MainActor func WhenInstallDateIsMoreThan14daysAgoDay14ThenRandomGeneratorIsRequestARandomNumberInTheCorrectRange() {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -16, to: Date())!
        userDefaults.set(twoWeeksAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(false, forKey: UserDefaultsWrapper<Bool>.Key.homePageUserInteractedWithSurveyDay0.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)

        XCTAssertEqual(randomNumberGenerator.capturedRange, 0..<100)
    }

    @MainActor func testWhenInstallDateIsLessThanADayAgoButUserNotIn10PercentNoSurveyCardIsShown() {
        let aDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        userDefaults.set(aDayAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        let randomGenerator = MockRandomNumberGenerator()
        randomGenerator.numberToReturn = 10
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults, randomNumberGenerator: randomGenerator)
        vm.shouldShowAllFeatures = true

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay0))
        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay14))

        userDefaults.set(aDayAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay0))
        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay14))
    }

    @MainActor func testWhenInstallDateIsMoreThanADayAgoButLessThanAWeekAgoNoSurveyCardIsShown() {
        let aDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        userDefaults.set(aDayAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)
        vm.shouldShowAllFeatures = true

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay0))
        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay14))

        userDefaults.set(aDayAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay0))
        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay14))
    }

    @MainActor func testWhenInstallDateIsMoreThan14daysAgoDay14SurveyCardIsShown() {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        userDefaults.set(twoWeeksAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(false, forKey: UserDefaultsWrapper<Bool>.Key.homePageUserInteractedWithSurveyDay0.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)
        vm.shouldShowAllFeatures = true

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay0))
        XCTAssertTrue(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay14))
    }

    @MainActor func testWhenInstallDateIsMoreThan14daysAgoDay14ButUserNotIn10percentSurveyCardIsNotShown() {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        userDefaults.set(twoWeeksAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(nil, forKey: UserDefaultsWrapper<Bool?>.Key.homePageShowSurveyDay14in10Percent.rawValue)
        userDefaults.set(false, forKey: UserDefaultsWrapper<Bool>.Key.homePageUserInteractedWithSurveyDay0.rawValue)

        let randomGenerator = MockRandomNumberGenerator()
        randomGenerator.numberToReturn = 10
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults, randomNumberGenerator: randomGenerator)
        vm.shouldShowAllFeatures = true

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay0))
        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay14))
    }

    @MainActor func testWhenInstallDateIsMoreThan15daysAgoDay14SurveyCardIsShown() {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -16, to: Date())!
        userDefaults.set(twoWeeksAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(false, forKey: UserDefaultsWrapper<Bool>.Key.homePageUserInteractedWithSurveyDay0.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)
        vm.shouldShowAllFeatures = true

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay0))
        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay14))
    }

    @MainActor func testWhenInstallDateIsMoreThan14daysAgoAndUserInteractedWithDay0SurveyDay14SurveyCardIsNotShown() {
        let statisticStore = MockStatisticsStore()
        vm.statisticsStore = statisticStore
        vm.performAction(for: .surveyDay0)
        let aDayAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        userDefaults.set(aDayAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(false, forKey: UserDefaultsWrapper<Bool>.Key.homePageUserInteractedWithSurveyDay0.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)
        vm.shouldShowAllFeatures = true

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay0))
        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay14))
    }

    @MainActor func testWhenInstallDateIsMoreThanAWeekAgoAndUserDismissedDay0SurveyDay14SurveyCardIsNotShown() {
        let statisticStore = MockStatisticsStore()
        vm.statisticsStore = statisticStore
        vm.removeItem(for: .surveyDay0)
        let aDayAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        userDefaults.set(aDayAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(false, forKey: UserDefaultsWrapper<Bool>.Key.homePageUserInteractedWithSurveyDay0.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)
        vm.shouldShowAllFeatures = true

        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay0))
        XCTAssertFalse(vm.visibleFeaturesMatrix.reduce([], +).contains(HomePage.Models.FeatureType.surveyDay14))
    }

    @MainActor func testWhenInitializedNotForTheFirstTimeTheMatrixHasAllElementsInTheRightOrder() {
        let homePageIsFirstSession = UserDefaultsWrapper<Bool>(key: .homePageIsFirstSession, defaultValue: true)
        homePageIsFirstSession.wrappedValue = false
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)
        vm.shouldShowAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix[0][0], HomePage.Models.FeatureType.defaultBrowser)
        // All cases minus two since it will show only one of the surveys and no NetP card
        XCTAssertEqual(vm.visibleFeaturesMatrix.reduce([], +).count, HomePage.Models.FeatureType.allCases.count - 1)
    }

    func testWhenTogglingShowAllFeatureThenCorrectElementsAreVisible() {
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay14])

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
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.defaultBrowser, .surveyDay14])

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
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay14, .importBookmarksAndPasswords])

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
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay14, .emailProtection])

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
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay14, .duckplayer])

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
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay14, .duckplayer])

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
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay14])

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
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay14, .duckplayer])

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
        XCTAssertEqual(tabCollectionVM.tabs[1].url, URL(string: vm.day0SurveyURL))
    }

    @MainActor func testWhenAskedToPerformActionForSurveyDay14ShowsTheSurveySite() {
        let atb = "someAtb"
        let statisticStore = MockStatisticsStore()
        statisticStore.atb = atb
        vm.statisticsStore = statisticStore

        vm.performAction(for: .surveyDay14)
        XCTAssertEqual(tabCollectionVM.tabs[1].url, URL(string: vm.day14SurveyURL))
    }

    @MainActor func testThatWhenIfAllFeatureActiveThenVisibleMatrixIsEmpty() {
        capturingDefaultBrowserProvider.isDefault = true
        emailStorage.isEmailProtectionEnabled = true
        duckPlayerPreferences.youtubeOverlayAnyButtonPressed = true
        capturingDataImportProvider.didImport = true
        userDefaults.set(false, forKey: UserDefaultsWrapper<Date>.Key.homePageShowSurveyDay0.rawValue)
        userDefaults.set(false, forKey: UserDefaultsWrapper<Date>.Key.homePageShowSurveyDay14.rawValue)

        vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: capturingDefaultBrowserProvider,
            dataImportProvider: capturingDataImportProvider,
            tabCollectionViewModel: tabCollectionVM,
            emailManager: emailManager,
            duckPlayerPreferences: duckPlayerPreferences,
            homePageRemoteMessaging: createMessaging()
        )

        XCTAssertEqual(vm.visibleFeaturesMatrix, [[]])
    }

    @MainActor func testDismissedItemsAreRemovedFromVisibleMatrixAndChoicesArePersisted() {
        vm.shouldShowAllFeatures = true
        let expectedMatrix = expectedFeatureMatrixWithout(types: [.surveyDay14])
        XCTAssertEqual(expectedMatrix, vm.visibleFeaturesMatrix)

        vm.removeItem(for: .surveyDay0)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.surveyDay0))

        userDefaults.set(Calendar.current.date(byAdding: .month, value: -1, to: Date())!, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        vm = HomePage.Models.ContinueSetUpModel.fixture(appGroupUserDefaults: userDefaults)

        vm.removeItem(for: .surveyDay14)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.surveyDay14))

        vm.removeItem(for: .defaultBrowser)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.defaultBrowser))

        vm.removeItem(for: .importBookmarksAndPasswords)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.importBookmarksAndPasswords))

        vm.removeItem(for: .duckplayer)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.duckplayer))

        vm.removeItem(for: .emailProtection)
        XCTAssertFalse(vm.visibleFeaturesMatrix.flatMap { $0 }.contains(.emailProtection))

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

    private func createMessaging() -> HomePageRemoteMessaging {
#if NETWORK_PROTECTION && DBP
        return HomePageRemoteMessaging(
            networkProtectionRemoteMessaging: MockNetworkProtectionRemoteMessaging(),
            networkProtectionUserDefaults: userDefaults,
            dataBrokerProtectionRemoteMessaging: MockDataBrokerProtectionRemoteMessaging(),
            dataBrokerProtectionUserDefaults: userDefaults
        )
#elseif NETWORK_PROTECTION
        return HomePageRemoteMessaging(
            networkProtectionRemoteMessaging: MockNetworkProtectionRemoteMessaging(),
            networkProtectionUserDefaults: userDefaults
        )
#elseif DBP
        return HomePageRemoteMessaging(
            dataBrokerProtectionRemoteMessaging: MockDataBrokerProtectionRemoteMessaging(),
            dataBrokerProtectionUserDefaults: userDefaults
        )
#else
        return HomePageRemoteMessaging.defaultMessaging()
#endif
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
        duckPlayerPreferences: DuckPlayerPreferencesPersistor = DuckPlayerPreferencesPersistorMock(),
        privacyConfig: MockPrivacyConfiguration = MockPrivacyConfiguration(),
        appGroupUserDefaults: UserDefaults,
        randomNumberGenerator: RandomNumberGenerating = MockRandomNumberGenerator()
    ) -> HomePage.Models.ContinueSetUpModel {
        privacyConfig.featureSettings = [
            "surveyCardDay0": "enabled",
            "surveyCardDay14": "enabled",
            "networkProtection": "disabled"
        ] as! [String: String]
        let manager = MockPrivacyConfigurationManager()
        manager.privacyConfig = privacyConfig

#if NETWORK_PROTECTION && DBP
        let messaging = HomePageRemoteMessaging(
            networkProtectionRemoteMessaging: MockNetworkProtectionRemoteMessaging(),
            networkProtectionUserDefaults: appGroupUserDefaults,
            dataBrokerProtectionRemoteMessaging: MockDataBrokerProtectionRemoteMessaging(),
            dataBrokerProtectionUserDefaults: appGroupUserDefaults
        )
#elseif NETWORK_PROTECTION
        let messaging = HomePageRemoteMessaging(
            networkProtectionRemoteMessaging: MockNetworkProtectionRemoteMessaging(),
            networkProtectionUserDefaults: appGroupUserDefaults
        )
#elseif DBP
        let messaging = HomePageRemoteMessaging(
            dataBrokerProtectionRemoteMessaging: MockDataBrokerProtectionRemoteMessaging(),
            dataBrokerProtectionUserDefaults: appGroupUserDefaults
        )
#else
        let messaging =  HomePageRemoteMessaging.defaultMessaging()
#endif

        return HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: defaultBrowserProvider,
            dataImportProvider: dataImportProvider,
            tabCollectionViewModel: TabCollectionViewModel(),
            emailManager: emailManager,
            duckPlayerPreferences: duckPlayerPreferences,
            homePageRemoteMessaging: messaging,
            privacyConfigurationManager: manager,
            randomNumberGenerator: randomNumberGenerator)
    }
}

class MockRandomNumberGenerator: RandomNumberGenerating {
    var numberToReturn = 0
    var capturedRange: Range<Int>?
    func random(in range: Range<Int>) -> Int {
        capturedRange = range
        return numberToReturn
    }
}
