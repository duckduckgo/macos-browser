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

    private var notificationView: NSView?
    private var hideTimer: Timer?

    func showUpdateNotification(icon: NSImage, text: String, buttonText: String? = nil) {
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
                                                              autoDismissDuration: 10,
                                                              onClick: { [weak self] in
                self?.openUpdatesPage()
            })

            viewController.show(onParent: windowController.mainViewController,
                                relativeTo: button)
        }
    }

    func closeUpdateNotification() {
        hideTimer?.invalidate()
        hideTimer = nil

        // Remove observer for window resize
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: nil)

        notificationView?.removeFromSuperview()
        notificationView = nil
    }

    @objc private func fadeOutNotification() {
        guard let view = notificationView else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 1/3
            view.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.closeUpdateNotification()
        }
    }

    @objc private func windowDidResize(_ notification: Notification) {
        guard let mainWindow = notification.object as? NSWindow,
              let notificationView = notificationView else { return }

        let notificationSize = notificationView.frame.size
        updateNotificationPosition(in: mainWindow, with: notificationView, notificationSize: notificationSize)
    }

    private func updateNotificationPosition(in window: NSWindow, with notificationView: NSView, notificationSize: CGSize) {
        let windowFrame = window.frame
        let notificationOrigin = NSPoint(x: windowFrame.width - notificationSize.width, y: windowFrame.height - notificationSize.height - 80)
        notificationView.setFrameOrigin(notificationOrigin)
    }

    func openUpdatesPage() {
        DispatchQueue.main.async {
            WindowControllersManager.shared.showTab(with: .releaseNotes)
        }
    }
}
