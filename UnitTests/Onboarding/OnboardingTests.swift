//
//  OnboardingTests.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

class OnboardingTests: XCTestCase {

    // swiftlint:disable:next weak_delegate
    let delegate = MockOnboardingDelegate()

    @UserDefaultsWrapper(key: .onboardingFinished, defaultValue: false)
    var onboardingFinished: Bool

    override func setUp() {
        super.setUp()
        onboardingFinished = false
    }

    func testWhenInitialisedThenStateIsStarted() {
        let model = OnboardingViewModel(delegate: nil)
        XCTAssertEqual(model.state, .startFlow)
    }

    @MainActor
    func testStateChanges() {
        let model = OnboardingViewModel(delegate: delegate)
        assertStateChange(model, .startFlow, .welcome, model.onSplashFinished)
        assertStateChange(model, .welcome, .importData, model.onStartPressed)
        assertStateChange(model, .importData, .setDefault, model.onImportPressed)
#if APPSTORE
        assertStateChange(model, .setDefault, .startBrowsing, model.onSetDefaultPressed)
#else
        assertStateChange(model, .setDefault, .addToDock, model.onSetDefaultPressed)
        assertStateChange(model, .addToDock, .startBrowsing, model.onAddToDockPressed)
#endif

        model.state = .importData
        assertStateChange(model, .importData, .setDefault, model.onImportSkipped)

        model.state = .setDefault
#if APPSTORE
        assertStateChange(model, .setDefault, .startBrowsing, model.onSetDefaultSkipped)
#else
        assertStateChange(model, .setDefault, .addToDock, model.onSetDefaultSkipped)
        assertStateChange(model, .addToDock, .startBrowsing, model.onAddToDockSkipped)
#endif
    }

    func testWhenImportPressedDelegateIsCalled() {
        let model = OnboardingViewModel(delegate: delegate)
        XCTAssertEqual(0, delegate.didRequestImportDataCalled)
        XCTAssertEqual(0, delegate.didRequestSetDefaultCalled)
        XCTAssertEqual(0, delegate.hasFinishedCalled)

        model.onImportSkipped()
        XCTAssertEqual(0, delegate.didRequestImportDataCalled)
        XCTAssertEqual(0, delegate.didRequestSetDefaultCalled)
        XCTAssertEqual(0, delegate.hasFinishedCalled)

        model.onImportPressed()
        XCTAssertEqual(1, delegate.didRequestImportDataCalled)
        XCTAssertEqual(0, delegate.didRequestSetDefaultCalled)
        XCTAssertEqual(0, delegate.hasFinishedCalled)
    }

    @MainActor
    func testWhenSetDefaultPressedDelegateIsCalled() {
        let model = OnboardingViewModel(delegate: delegate)
        XCTAssertEqual(0, delegate.didRequestImportDataCalled)
        XCTAssertEqual(0, delegate.didRequestSetDefaultCalled)
        XCTAssertEqual(0, delegate.hasFinishedCalled)

        model.onSetDefaultSkipped()
        XCTAssertEqual(0, delegate.didRequestImportDataCalled)
        XCTAssertEqual(0, delegate.didRequestSetDefaultCalled)
        XCTAssertEqual(0, delegate.didRequestAddToDockCalled)
#if APPSTORE
        XCTAssertEqual(1, delegate.hasFinishedCalled)
#else
        XCTAssertEqual(0, delegate.hasFinishedCalled)
#endif

        model.onSetDefaultPressed()
        XCTAssertEqual(0, delegate.didRequestImportDataCalled)
        XCTAssertEqual(0, delegate.didRequestAddToDockCalled)
        XCTAssertEqual(1, delegate.didRequestSetDefaultCalled)
#if APPSTORE
        XCTAssertEqual(2, delegate.hasFinishedCalled)
#else
        XCTAssertEqual(0, delegate.hasFinishedCalled)
#endif

#if !APPSTORE
        model.onAddToDockSkipped()
        XCTAssertEqual(0, delegate.didRequestImportDataCalled)
        XCTAssertEqual(1, delegate.didRequestSetDefaultCalled)
        XCTAssertEqual(0, delegate.didRequestAddToDockCalled)
        XCTAssertEqual(1, delegate.hasFinishedCalled)
#endif

#if !APPSTORE
        model.onAddToDockPressed()
        XCTAssertEqual(0, delegate.didRequestImportDataCalled)
        XCTAssertEqual(1, delegate.didRequestSetDefaultCalled)
        XCTAssertEqual(2, delegate.hasFinishedCalled)
#endif

        XCTAssertTrue(onboardingFinished)
    }

    func testThatOnboardingFinishedDoesNotInfluenceInitialState() {
        onboardingFinished = true
        let model = OnboardingViewModel()
        XCTAssertEqual(model.state, .startFlow)
    }

    @MainActor
    private func assertStateChange(_ model: OnboardingViewModel,
                                   _ expectedCurrentState: OnboardingViewModel.OnboardingPhase,
                                   _ expectedFinalState: OnboardingViewModel.OnboardingPhase,
                                   _ mutator: @MainActor () -> Void,
                                   file: StaticString = #file,
                                   line: UInt = #line) {

        XCTAssertEqual(model.state, expectedCurrentState, file: file, line: line)
        mutator()
        XCTAssertEqual(model.state, expectedFinalState, file: file, line: line)

    }

}

final class MockOnboardingDelegate: NSObject, OnboardingDelegate {
    var didRequestImportDataCalled = 0
    var didRequestSetDefaultCalled = 0
    var didRequestAddToDockCalled = 0
    var hasFinishedCalled = 0

    func onboardingDidRequestImportData(completion: @escaping () -> Void) {
        didRequestImportDataCalled += 1
        completion()
    }

    func onboardingDidRequestSetDefault(completion: @escaping () -> Void) {
        didRequestSetDefaultCalled += 1
        completion()
    }

    func onboardingDidRequestAddToDock(completion: @escaping () -> Void) {
        didRequestAddToDockCalled += 1
        completion()
    }

    func onboardingHasFinished() {
        hasFinishedCalled += 1
    }

}
