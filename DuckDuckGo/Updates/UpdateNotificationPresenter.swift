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

final class UpdateNotificationPresenter {

    static let presentationTimeInterval: TimeInterval = 10

    func showUpdateNotification(icon: NSImage, text: String, buttonText: String? = nil, presentMultiline: Bool = false) {
        DispatchQueue.main.async {
            guard let mainWindow = NSApp.mainWindow as? MainWindow,
                  let windowController = mainWindow.windowController as? MainWindowController,
                  let button = windowController.mainViewController.navigationBarViewController.optionsButton else { return }

            let buttonAction: (() -> Void)? = { [weak self] in
                self?.openUpdatesPage()
            }

            let viewController = PopoverMessageViewController(message: text,
                                                              image: icon,
                                                              buttonText: buttonText,
                                                              buttonAction: buttonAction,
                                                              shouldShowCloseButton: buttonText == nil,
                                                              presentMultiline: presentMultiline,
                                                              autoDismissDuration: Self.presentationTimeInterval,
                                                              onClick: { [weak self] in
                self?.openUpdatesPage()
            })

            viewController.show(onParent: windowController.mainViewController,
                                relativeTo: button)
        }
    }

    func openUpdatesPage() {
        DispatchQueue.main.async {
            WindowControllersManager.shared.showTab(with: .releaseNotes)
        }
    }
}
