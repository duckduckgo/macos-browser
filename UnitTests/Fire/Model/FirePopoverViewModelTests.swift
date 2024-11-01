//
//  FirePopoverViewModelTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

final class FirePopoverViewModelTests: XCTestCase {

    @MainActor
    private func makeViewModel(with tabCollectionViewModel: TabCollectionViewModel, contextualOnboardingStateMachine: ContextualOnboardingStateUpdater = ContextualOnboardingStateMachine()) -> FirePopoverViewModel {
        let manager = WebCacheManagerMock()
        let historyCoordinator = HistoryCoordinatingMock()
        let permissionManager = PermissionManagerMock()
        let faviconManager = FaviconManagerMock()
        let fire = Fire(cacheManager: manager,
                        historyCoordinating: historyCoordinator,
                        permissionManager: permissionManager,
                        windowControllerManager: WindowControllersManager.shared,
                        faviconManagement: faviconManager,
                        tld: ContentBlocking.shared.tld)
        return FirePopoverViewModel(
            fireViewModel: .init(fire: fire),
            tabCollectionViewModel: tabCollectionViewModel,
            historyCoordinating: HistoryCoordinatingMock(),
            fireproofDomains: FireproofDomains(store: FireproofDomainsStoreMock()),
            faviconManagement: FaviconManagerMock(),
            tld: ContentBlocking.shared.tld,
            contextualOnboardingStateMachine: contextualOnboardingStateMachine
        )
    }

    @MainActor func testOnBurn_OnboardingStateMachineFireButtonUsedCalled() {
        // Given
        let tabCollectionVM = TabCollectionViewModel()
        let stateMachine = CapturingContextualOnboardingStateUpdater()
        let vm = makeViewModel(with: tabCollectionVM, contextualOnboardingStateMachine: stateMachine)
        XCTAssertNil(stateMachine.updatedForTab)
        XCTAssertFalse(stateMachine.gotItPressedCalled)
        XCTAssertFalse(stateMachine.fireButtonUsedCalled)

        // When
        vm.burn()

        // Then
        XCTAssertNil(stateMachine.updatedForTab)
        XCTAssertFalse(stateMachine.gotItPressedCalled)
        XCTAssertTrue(stateMachine.fireButtonUsedCalled)
    }
}

class CapturingContextualOnboardingStateUpdater: ContextualOnboardingStateUpdater {

    var state: ContextualOnboardingState = .onboardingCompleted

    var updatedForTab: Tab?
    var gotItPressedCalled = false
    var fireButtonUsedCalled = false

    func updateStateFor(tab: Tab) {
        updatedForTab = tab
    }

    func gotItPressed() {
        gotItPressedCalled = true
    }

    func fireButtonUsed() {
        fireButtonUsedCalled = true
    }

    func turnOffFeature() {}

}
