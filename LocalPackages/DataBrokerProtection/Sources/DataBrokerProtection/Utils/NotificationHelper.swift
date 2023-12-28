//
//  NotificationHelper.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Foundation
import UserNotifications

struct NotificationHelper {
    struct NotificationIdentifier {
        static let bundleID = Bundle.main.bundleIdentifier ?? "com.duckduckgo.dbp.agent"
        static let scanComplete = "\(NotificationIdentifier.bundleID).scan.complete"
    }

    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            // TODO: Send pixel with permission status?
            if let error = error {
                // Handle the error
                print("Error requesting notification permission: \(error.localizedDescription)")
            } else if granted {
                // Permission granted
                print("Notification permission granted")
            } else {
                // Permission denied
                print("Notification permission denied")
            }
        }
    }

    func sendFirstScanCompletedNotification() {
        let notificationContent = UNMutableNotificationContent()

        notificationContent.title = "Scan complete!"
        notificationContent.body = "DuckDuckGo has started the process to remove records matching your personal info online. See what we found..."

        let notificationIdentifier = NotificationIdentifier.scanComplete

        let request = UNNotificationRequest(identifier: notificationIdentifier, content: notificationContent, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                print("Notification sent")
            }
        }
    }
    
    func sendFirstRemovedNotification() {
        let notificationContent = UNMutableNotificationContent()
        
        notificationContent.title = "Success! A record of your info was removed!"
        notificationContent.body = "That’s one less creepy site storing and selling your personal info online. Check progress..."
        
        let notificationIdentifier = NotificationIdentifier.scanComplete
        
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: notificationContent, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                print("Notification sent")
            }
        }
    }
}
