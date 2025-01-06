//
//  UpdateNotificationPresenter.swift
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

import Cocoa
import SwiftUI
import Common
import os.log

final class UpdateNotificationPresenter {

    static let presentationTimeInterval: TimeInterval = 10

    func showUpdateNotification(icon: NSImage, text: String, buttonText: String? = nil, presentMultiline: Bool = false) {
        Logger.updates.log("Notification presented: \(text, privacy: .public)")

        DispatchQueue.main.async {
            guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController ?? WindowControllersManager.shared.mainWindowControllers.last,
                  let button = windowController.mainViewController.navigationBarViewController.optionsButton else {
                return
            }

            let parentViewController = windowController.mainViewController

            guard parentViewController.view.window?.isKeyWindow == true, (parentViewController.presentedViewControllers ?? []).isEmpty else {
                return
            }

            let buttonAction: (() -> Void)? = { [weak self] in
                self?.openUpdatesPage()
            }

            let viewController = PopoverMessageViewController(message: text,
                                                              image: icon,
                                                              buttonText: buttonText,
                                                              buttonAction: buttonAction,
                                                              shouldShowCloseButton: true,
                                                              presentMultiline: presentMultiline,
                                                              autoDismissDuration: Self.presentationTimeInterval,
                                                              onClick: { [weak self] in
                self?.openUpdatesPage()
            })

            viewController.show(onParent: parentViewController, relativeTo: button)
        }
    }

    func openUpdatesPage() {
        DispatchQueue.main.async {
            WindowControllersManager.shared.showTab(with: .releaseNotes)
        }
    }
}
