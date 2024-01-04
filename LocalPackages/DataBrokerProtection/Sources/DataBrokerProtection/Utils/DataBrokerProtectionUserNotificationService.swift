//
//  DataBrokerProtectionUserNotificationService.swift
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
import Common

public protocol DataBrokerProtectionUserNotificationService {
    func requestNotificationPermission()
    func sendFirstScanCompletedNotification()
    func sendFirstRemovedNotificationIfPossible()
    func sendAllInfoRemovedNotificationIfPossible()
    func scheduleCheckInNotificationIfPossible()
}

public struct DefaultDataBrokerProtectionUserNotificationService: DataBrokerProtectionUserNotificationService {
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let userDefaults: UserDefaults

    public init(pixelHandler: EventMapping<DataBrokerProtectionPixels>, userDefaults: UserDefaults = .standard) {
        self.pixelHandler = pixelHandler
        self.userDefaults = userDefaults
    }

    public func requestNotificationPermission() {
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

    private func sendNotification(_ notification: UserNotification) {
        let notificationContent = UNMutableNotificationContent()

        notificationContent.title = notification.title
        notificationContent.body = notification.message

        let notificationIdentifier = notification.identifier

        let request = UNNotificationRequest(identifier: notificationIdentifier, content: notificationContent, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                print("Notification sent")
            }
        }
    }

    private func sendScheduledNotification(_ notification: UserNotification, forAfterDays days: Int) {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = notification.title
        notificationContent.body = notification.message

        let notificationIdentifier = notification.identifier

        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: days, to: Date()) else {
            os_log("Notification scheduled for a invalid date", log: .dataBrokerProtection)
            return
        }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: notificationIdentifier, content: notificationContent, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                print("Notification scheduled")
            }
        }
    }

    public func sendFirstScanCompletedNotification() {
        sendNotification(.firstScanComplete)
    }

    public func sendFirstRemovedNotificationIfPossible() {
       // if userDefaults[.didSendFirstRemovedNotification] != true {
            sendNotification(.firstProfileRemoved)
            userDefaults[.didSendFirstRemovedNotification]  = true
       // }
    }

    public func sendAllInfoRemovedNotificationIfPossible() {
      //  if userDefaults[.didSendAllInfoRemovedNotification] != true {
            sendNotification(.allInfoRemoved)
            userDefaults[.didSendAllInfoRemovedNotification]  = true
       // }
    }

    public func scheduleCheckInNotificationIfPossible() {
       // if userDefaults[.didSendCheckedInNotification] != true {
        sendScheduledNotification(.checkIn, forAfterDays: 14)
            userDefaults[.didSendCheckedInNotification]  = true
       // }
    }

}

private enum UserNotification {
    case firstScanComplete
    case firstProfileRemoved
    case allInfoRemoved
    case checkIn

    var title: String {
        switch self {
        case .firstScanComplete:
            return "Scan complete!"
        case .firstProfileRemoved:
            return "Success! A record of your info was removed!"
        case .allInfoRemoved:
            return "All pending info removals complete!"
        case .checkIn:
            return "We're making progress on your info removals"
        }
    }

    var message: String {
        switch self {
        case .firstScanComplete:
            return "DuckDuckGo has started the process to remove records matching your personal info online. See what we found..."
        case .firstProfileRemoved:
            return "That’s one less creepy site storing and selling your personal info online. Check progress..."
        case .allInfoRemoved:
            return "See all the records matching your personal info that DuckDuckGo found and removed from the web..."
        case .checkIn:
            return "See the records matching your personal info that DuckDuckGo found and removed from the web so far..."
        }
    }

    var identifier: String {
        let notificationPrefix = "data.broker.protection.user.notification"

        switch self {
        case .firstScanComplete:
            return "\(notificationPrefix).scan.complete"
        case .firstProfileRemoved:
            return "\(notificationPrefix).first.removed"
        case .allInfoRemoved:
            return "\(notificationPrefix).all.removed"
        case .checkIn:
            return "\(notificationPrefix).check-in"
        }
    }
}

private extension UserDefaults {
    enum Key: String {
        case didSendFirstRemovedNotification
        case didSendAllInfoRemovedNotification
        case didSendCheckedInNotification
    }

    subscript<T>(key: Key) -> T? where T: Any {
        get {
            return value(forKey: key.rawValue) as? T
        }
        set {
            set(newValue, forKey: key.rawValue)
        }
    }

}
