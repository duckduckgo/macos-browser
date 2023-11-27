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
import Carbon.HIToolbox
import Combine
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

    @IBOutlet var backgroundImageView: NSImageView! {
        didSet {
            // NSImageView magic to improve image resizing performance.
            backgroundImageView.layer = CALayer()
            backgroundImageView.layer?.contentsGravity = .resizeAspectFill
            backgroundImageView.layer?.contents = backgroundImageView.image
        }
    }

    private weak var delegate: OnboardingDelegate?

    private let model = OnboardingViewModel()

    private var mouseDownMonitor: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        model.delegate = delegate
        let host = NSHostingView(rootView: Onboarding.RootView().environmentObject(model))
        view.addAndLayout(host)

        mouseDownMonitor = NSEvent.addLocalCancellableMonitor(forEventsMatching: [.leftMouseDown, .otherMouseDown, .keyDown]) { [weak self] event in
            dispatchPrecondition(condition: .onQueue(.main))
            if event.type == .keyDown && event.keyCode != kVK_Escape {
                return event
            }
            self?.model.skipTyping()
            return event
        }
    }

}
