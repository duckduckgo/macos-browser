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

    override func setUp() {
        vm = HomePage.Models.ContinueSetUpModel()
    }

    override func tearDown() {
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
}
