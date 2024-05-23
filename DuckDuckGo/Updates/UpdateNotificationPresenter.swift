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

    private var notificationWindow: UpdateNotificationWindow?

    func showUpdateNotification(icon: NSImage, text: String) {
        let notificationSize = NSRect(x: 0, y: 0, width: 300, height: 40)

        let updateNotificationView = UpdateNotificationView(icon: icon, text: text) { [weak self] in
            self?.closeUpdateNotification()
        }
        let hostingController = NSHostingController(rootView: updateNotificationView)
        let notificationWindow = UpdateNotificationWindow(contentRect: notificationSize, styleMask: .borderless, backing: .buffered, defer: false)
        notificationWindow.contentView = hostingController.view

        let screenFrame = NSScreen.main!.frame
        notificationWindow.setFrameOrigin(NSPoint(x: screenFrame.width - notificationSize.width - 20, y: screenFrame.height - notificationSize.height - 40))

        self.notificationWindow = notificationWindow
    }

    func closeUpdateNotification() {
        notificationWindow?.orderOut(nil)
        notificationWindow = nil
    }
}
