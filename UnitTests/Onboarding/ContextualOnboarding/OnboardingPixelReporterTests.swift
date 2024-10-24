//
//  OnboardingPixelReporterTests.swift
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

import XCTest
import PixelKit
@testable import DuckDuckGo_Privacy_Browser

final class OnboardingPixelReporterTests: XCTestCase {

    var reporter: OnboardingPixelReporter!
    var onboardingState: MockContextualOnboardingState!
    var eventSent: PixelKitEventV2?
    var frequency: PixelKit.Frequency?

    override func setUpWithError() throws {
        onboardingState = MockContextualOnboardingState()
        reporter = OnboardingPixelReporter(onboardingStateProvider: onboardingState, fireAction: { [weak self] event, frequency  in
            self?.eventSent = event
            self?.frequency = frequency
        })
    }

    override func tearDownWithError() throws {
        onboardingState = nil
        reporter = nil
        eventSent = nil
        frequency = nil
    }

    func test_WhenTrackSiteSuggetionOptionTapped_ThenSiteSuggetionOptionTappedEventSent() throws {
        reporter.trackSiteSuggetionOptionTapped()
        XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.siteSuggetionOptionTapped.name)
        XCTAssertEqual(frequency, .unique)
    }

    func test_WhenTrackSearchSuggetionOptionTapped_ThenSearchSuggetionOptionTappedEventSent() throws {
        reporter.trackSearchSuggetionOptionTapped()
        XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.searchSuggetionOptionTapped.name)
        XCTAssertEqual(frequency, .unique)
    }

    func test_WhenTrackAddressBarTypedIn_ThenDependingOnTheState_CorrectPixelsAreSent() throws {
        for state in ContextualOnboardingState.allCases {
            eventSent = nil
            frequency = nil
            onboardingState.state = state
            reporter.trackAddressBarTypedIn()
            if state == .showTryASearch {
                XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.onboardingSearchCustom.name)
                XCTAssertEqual(frequency, .unique)
            } else if state == .showTryASite {
                XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.onboardingVisitSiteCustom.name)
                XCTAssertEqual(frequency, .unique)
            } else {
                XCTAssertNil(eventSent)
                XCTAssertNil(frequency)
            }
        }
    }

    func test_WhenTrackFireButtonSkipped_ThenOnboardingFireButtonPromptSkipPressedSent() {
        reporter.trackFireButtonSkipped()
        XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.onboardingFireButtonPromptSkipPressed.name)
        XCTAssertEqual(frequency, .unique)
    }

    func test_WhenTrackFireButtonTryIt_ThenOnboardingFireButtonTryItPressedSent() {
        reporter.trackFireButtonTryIt()
        XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.onboardingFireButtonTryItPressed.name)
        XCTAssertEqual(frequency, .unique)
    }
}

class MockContextualOnboardingState: ContextualOnboardingStateUpdater {
    var state: ContextualOnboardingState = .onboardingCompleted

    func updateStateFor(tab: Tab) {
    }

    func gotItPressed() {
    }

    func fireButtonUsed() {
    }

}
