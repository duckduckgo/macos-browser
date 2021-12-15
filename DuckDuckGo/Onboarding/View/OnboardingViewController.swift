//
//  OnboardingViewController.swift
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

import AppKit
import SwiftUI

final class OnboardingViewController: NSViewController {

    static func create(withDelegate delegate: OnboardingDelegate) -> Self {
        let storyboard = NSStoryboard(name: "Onboarding", bundle: nil)
        // swiftlint:disable force_cast
        let controller = storyboard.instantiateController(withIdentifier: "Onboarding") as! Self
        controller.delegate = delegate
        // swiftlint:enable force_cast
        return controller
    }

    weak var delegate: OnboardingDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = NSHostingView(rootView: Onboarding.RootView().environmentObject(OnboardingViewModel(delegate: delegate)))
        view.addAndLayout(host)
    }

}
