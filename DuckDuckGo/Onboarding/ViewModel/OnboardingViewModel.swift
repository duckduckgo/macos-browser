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

protocol OnboardingDelegate: NSObjectProtocol {

    /// Import data UI should be launched.  Whatever happens, call the completion to move on to the next screen.
    func onboardingDidRequestImportData(completion: @escaping () -> Void)

    /// Request set default should be launched.  Whatever happens, call the completion to move on to the next screen.
    func onboardingDidRequestSetDefault(completion: @escaping () -> Void)

    /// Has finished, but still showing a screen.  This is when to re-enable the UI.
    func onboardingHasFinished()

    /// Start browsing button pressed.  Close this and open the home tab.
    func onboardingDidRequestStartBrowsing()

}

final class OnboardingViewModel: ObservableObject {

    enum OnboardingPhase {

        case start
        case welcome
        case importData
        case setDefault
        case startBrowsing

    }

    @Published var state = OnboardingPhase.start

    weak var delegate: OnboardingDelegate?

    init(delegate: OnboardingDelegate?) {
        self.delegate = delegate
    }

    func onSplashFinished() {
        state = .welcome
    }

    func onStartPressed() {
        Pixel.fire(.onboardingStartPressed)
        state = .importData
    }

    func onImportPressed() {
        Pixel.fire(.onboardingImportPressed)
        delegate?.onboardingDidRequestImportData { [weak self] in
            self?.state = .setDefault
        }
    }

    func onImportSkipped() {
        Pixel.fire(.onboardingImportSkipped)
        state = .setDefault
    }

    func onSetDefaultPressed() {
        Pixel.fire(.onboardingSetDefaultPressed)
        delegate?.onboardingDidRequestSetDefault { [weak self] in
            self?.state = .startBrowsing
        }
    }

    func onSetDefaultSkipped() {
        Pixel.fire(.onboardingSetDefaultSkipped)
        state = .startBrowsing
    }

}
