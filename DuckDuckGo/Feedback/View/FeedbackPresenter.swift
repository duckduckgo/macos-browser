//
//  FeedbackPresenter.swift
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

import Cocoa

enum FeedbackPresenter {

    @MainActor
    static func presentFeedbackForm() {
        // swiftlint:disable:next force_cast
        let windowController = NSStoryboard.feedback.instantiateController(withIdentifier: "FeedbackWindowController") as! NSWindowController

        guard let feedbackWindow = windowController.window as? FeedbackWindow,
              let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController else {
            assertionFailure("FeedbackPresenter: Failed to present FeedbackWindow")
            return
        }

        feedbackWindow.feedbackViewController.currentTab =
            parentWindowController.mainViewController.tabCollectionViewModel.selectedTabViewModel?.tab
        parentWindowController.window?.beginSheet(feedbackWindow) { _ in }
    }

}

fileprivate extension NSStoryboard {

    static let feedback = NSStoryboard(name: "Feedback", bundle: .main)

}
