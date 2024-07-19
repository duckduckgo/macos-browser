//
//  OnboardingViewModel.swift
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

import SwiftUI
import PixelKit

protocol OnboardingDelegate: NSObjectProtocol {

    /// Import data UI should be launched.  Whatever happens, call the completion to move on to the next screen.
    func onboardingDidRequestImportData(completion: @escaping () -> Void)

    /// Request set default should be launched.  Whatever happens, call the completion to move on to the next screen.
    func onboardingDidRequestSetDefault(completion: @escaping () -> Void)

    /// Adding to the Dock should be launched.  Whatever happens, call the completion to move on to the next screen.
    func onboardingDidRequestAddToDock(completion: @escaping () -> Void)

    /// Has finished, but still showing a screen.  This is when to re-enable the UI.
    func onboardingHasFinished()

}

final class OnboardingViewModel: ObservableObject {

    enum OnboardingPhase {

        case startFlow
        case welcome
        case importData
        case setDefault
        case addToDock
        case startBrowsing

    }

    var typingDisabled = false
    var addToDockPressed = false

    @Published var skipTypingRequested = false
    @Published var state: OnboardingPhase = .startFlow {
        didSet {
            skipTypingRequested = false

            if state == .addToDock {
                PixelKit.fire(GeneralPixel.addToDockOnboardingStepPresented,
                              includeAppVersionParameter: false)
            }
            if state == .startBrowsing {
                PixelKit.fire(GeneralPixel.startBrowsingOnboardingStepPresented,
                              includeAppVersionParameter: false)
            }
        }
    }

    @UserDefaultsWrapper(key: .onboardingFinished, defaultValue: false)
    private static var _isOnboardingFinished: Bool

    @MainActor
    private(set) static var isOnboardingFinished: Bool {
        get {
            guard !_isOnboardingFinished else { return true }

            // when there‘s a restored state but Onboarding Finished flag is not set - set it
            guard WindowsManager.mainWindows.count <= 1 else {
                OnboardingViewModel.isOnboardingFinished = true
                return true
            }

            return false
        }
        set {
            _isOnboardingFinished = newValue
        }
    }

    weak var delegate: OnboardingDelegate?

    init(delegate: OnboardingDelegate? = nil) {
        self.delegate = delegate
    }

    func onSplashFinished() {
        state = .welcome
    }

    func onStartPressed() {
        state = .importData
    }

    func onImportPressed() {
        delegate?.onboardingDidRequestImportData { [weak self] in
            self?.state = .setDefault
        }
    }

    func onImportSkipped() {
        state = .setDefault
    }

    @MainActor
    func onSetDefaultPressed() {
        delegate?.onboardingDidRequestSetDefault { [weak self] in
#if !APPSTORE
            self?.state = .addToDock
#else
            self?.state = .startBrowsing
            Self.isOnboardingFinished = true
            self?.delegate?.onboardingHasFinished()
#endif
        }
    }

    @MainActor
    func onSetDefaultSkipped() {
#if !APPSTORE
        state = .addToDock
#else
        state = .startBrowsing
        Self.isOnboardingFinished = true
        delegate?.onboardingHasFinished()
#endif
    }

    @MainActor
    func onAddToDockPressed() {
        PixelKit.fire(GeneralPixel.userAddedToDockDuringOnboarding,
                      includeAppVersionParameter: false)
        addToDockPressed = true
        delegate?.onboardingDidRequestAddToDock { [weak self] in
            self?.state = .startBrowsing
            Self.isOnboardingFinished = true
            self?.delegate?.onboardingHasFinished()
        }
    }

    @MainActor
    func onAddToDockSkipped() {
        PixelKit.fire(GeneralPixel.userSkippedAddingToDockFromOnboarding,
                      includeAppVersionParameter: false)
        state = .startBrowsing
        Self.isOnboardingFinished = true
        delegate?.onboardingHasFinished()
    }

    func skipTyping() {
        skipTypingRequested = true
    }

    @MainActor
    func onboardingReshown() {
        if Self.isOnboardingFinished {
            typingDisabled = true
            delegate?.onboardingHasFinished()
        } else {
            state = .startFlow
        }
    }

}
