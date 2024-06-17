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

    static let presentationTimeInterval: TimeInterval = 5

    private var notificationWindow: UpdateNotificationWindow?
    private var hideTimer: Timer?

    func showUpdateNotification(icon: NSImage, text: String) {
        // Close the current notification if it's still visible
        closeUpdateNotification()

        let notificationSize = NSRect(x: 0, y: 0, width: 300, height: 60)

        let updateNotificationView = UpdateNotificationView(icon: icon, text: text, onClose: { [weak self] in
            self?.closeUpdateNotification()
        }, onTap: { [weak self] in
            self?.closeUpdateNotification()
            self?.openUpdatesPage()
        })
        let hostingController = NSHostingController(rootView: updateNotificationView)
        let notificationWindow = UpdateNotificationWindow(contentRect: notificationSize, styleMask: .borderless, backing: .buffered, defer: false)
        notificationWindow.contentView = hostingController.view

        let screenFrame = NSScreen.main!.frame
        notificationWindow.setFrameOrigin(NSPoint(x: screenFrame.width - notificationSize.width, y: screenFrame.height - notificationSize.height - 140))

        self.notificationWindow = notificationWindow

        // Set a timer to automatically hide the notification after 10 seconds
        hideTimer = Timer.scheduledTimer(timeInterval: Self.presentationTimeInterval, target: self, selector: #selector(fadeOutNotification), userInfo: nil, repeats: false)
    }

    func closeUpdateNotification() {
        hideTimer?.invalidate()
        hideTimer = nil
        notificationWindow?.orderOut(nil)
        notificationWindow = nil
    }

    @objc private func fadeOutNotification() {
        guard let window = notificationWindow else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 1/3
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.closeUpdateNotification()
        }
    }

    func openUpdatesPage() {
        //TODO: Open Updates page
        DispatchQueue.main.async {
            WindowControllersManager.shared.showTab(with: .newtab)
        }
    }

}
