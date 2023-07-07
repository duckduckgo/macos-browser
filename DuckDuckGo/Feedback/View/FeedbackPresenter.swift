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
import DependencyInjection

#if swift(>=5.9)
@Injectable
#endif
final class FeedbackPresenter: Injectable {

    let dependencies: DependencyStorage

    @Injected
    var windowManager: WindowManagerProtocol

    typealias InjectedDependencies = FeedbackViewController.Dependencies

    private init() { fatalError("\(Self.self) should not be instantiated") }

    @MainActor
    static func presentFeedbackForm(with dependencyProvider: DependencyProvider) {
        let dependencies = DependencyStorage(dependencyProvider)
        guard let parentWindowController = dependencies.windowManager.lastKeyMainWindowController else {
            assertionFailure("FeedbackPresenter: Failed to present FeedbackWindow")
            return
        }

        let feedbackWindow = FeedbackWindow(dependencyProvider: dependencyProvider,
                                            currentTab: parentWindowController.mainViewController.tabCollectionViewModel.selectedTabViewModel?.tab)
        parentWindowController.window?.beginSheet(feedbackWindow)
    }

}
