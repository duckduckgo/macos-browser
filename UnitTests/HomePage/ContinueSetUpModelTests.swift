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

final class ContinueSetUpModelTests: XCTestCase {

    var vm: HomePage.Models.ContinueSetUpModel!
    var capturingDefaultBrowserProvider: CapturingDefaultBrowserProvider!
    var capturingDataImportProvider: CapturingDataImportProvider!

    override func setUp() {
        capturingDefaultBrowserProvider = CapturingDefaultBrowserProvider()
        capturingDataImportProvider = CapturingDataImportProvider()
        vm = HomePage.Models.ContinueSetUpModel(defaultBrowserProvider: capturingDefaultBrowserProvider, dataImportProvider: capturingDataImportProvider)
    }

    override func tearDown() {
        capturingDefaultBrowserProvider = nil
        capturingDataImportProvider = nil
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

    func testDoesIsMoreOrLessButtonNeededReturnTheExpectedValue() {
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

        vm.showAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.showAllFeatures = false

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
        capturingDefaultBrowserProvider.isDefault = true
        var features = HomePage.Models.FeatureType.allCases
        vm = HomePage.Models.ContinueSetUpModel.fixture(defaultBrowserProvider: capturingDefaultBrowserProvider)
        let defaultBrowserIdex = features.firstIndex(of: .defaultBrowser)!
        features.remove(at: defaultBrowserIdex)
        let expectedMatrix = features.chunked(into: HomePage.featuresPerRow)

        vm.showAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.showAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
        XCTAssertEqual(vm.visibleFeaturesMatrix, [expectedMatrix[0]])
    }

    func testWhenAskedToPerformActionForImportPromptThrowsThenItOpensImportWindow() {
        vm.performAction(for: .importBookmarksAndPasswords)

        XCTAssertTrue(capturingDataImportProvider.showImportWindowCalled)
    }

    func testWhenUserHasUsedImportAndTogglingShowAllFeatureTheCorrectElementsAreVisible() {
        capturingDataImportProvider.hasUserUsedImport = true
        var features = HomePage.Models.FeatureType.allCases
        vm = HomePage.Models.ContinueSetUpModel.fixture(dataImportProvider: capturingDataImportProvider)
        let importIdex = features.firstIndex(of: .importBookmarksAndPasswords)!
        features.remove(at: importIdex)
        let expectedMatrix = features.chunked(into: HomePage.featuresPerRow)

        vm.showAllFeatures = true

        XCTAssertEqual(vm.visibleFeaturesMatrix, expectedMatrix)

        vm.showAllFeatures = false

        XCTAssertEqual(vm.visibleFeaturesMatrix.count, 1)
        XCTAssertTrue(vm.visibleFeaturesMatrix[0].count <= HomePage.featuresPerRow)
        XCTAssertEqual(vm.visibleFeaturesMatrix, [expectedMatrix[0]])
    }
}

class CapturingDataImportProvider: DataImportProvider {
    var showImportWindowCalled = false
    var hasUserUsedImport = false

    func showImportWindow() {
        showImportWindowCalled = true
    }
}

extension HomePage.Models.ContinueSetUpModel {
    static func fixture(defaultBrowserProvider: DefaultBrowserProvider = CapturingDefaultBrowserProvider(), dataImportProvider: DataImportProvider = CapturingDataImportProvider()) -> HomePage.Models.ContinueSetUpModel {
        HomePage.Models.ContinueSetUpModel(defaultBrowserProvider: defaultBrowserProvider, dataImportProvider: dataImportProvider)
    }
}
