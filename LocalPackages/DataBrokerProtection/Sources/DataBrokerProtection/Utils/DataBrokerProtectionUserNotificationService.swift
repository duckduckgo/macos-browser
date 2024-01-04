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
import AppKit

public protocol DataBrokerProtectionUserNotificationService {
    func requestNotificationPermission()
    func sendFirstScanCompletedNotification()
    func sendFirstRemovedNotificationIfPossible()
    func sendAllInfoRemovedNotificationIfPossible()
    func scheduleCheckInNotificationIfPossible()
}

public class DefaultDataBrokerProtectionUserNotificationService: NSObject, DataBrokerProtectionUserNotificationService {
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let userDefaults: UserDefaults
    private let userNotificationCenter: UNUserNotificationCenter

    public init(pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                userDefaults: UserDefaults = .standard,
                userNotificationCenter: UNUserNotificationCenter = .current()) {
        self.pixelHandler = pixelHandler
        self.userDefaults = userDefaults
        self.userNotificationCenter = userNotificationCenter

        super.init()

        self.userNotificationCenter.delegate = self
    }

    public func requestNotificationPermission() {
        userNotificationCenter.requestAuthorization(options: [.alert]) { granted, error in
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

    private func sendNotification(_ notification: UserNotification, afterDays days: Int? = nil) {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = notification.title
        notificationContent.body = notification.message

        if #available(macOS 12, *) {
            notificationContent.interruptionLevel = .active
        }

        let request: UNNotificationRequest

        if let days = days {
            let calendar = Calendar.current
            guard let date = calendar.date(byAdding: .day, value: days, to: Date()) else {
                os_log("Notification scheduled for an invalid date", log: .dataBrokerProtection)
                return
            }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            request = UNNotificationRequest(identifier: notification.identifier, content: notificationContent, trigger: trigger)
        } else {
            request = UNNotificationRequest(identifier: notification.identifier, content: notificationContent, trigger: nil)
        }

        userNotificationCenter.add(request) { error in
            if error == nil {
                if days != nil {
                    os_log("Notification scheduled", log: .dataBrokerProtection)
                } else {
                    os_log("Notification sent", log: .dataBrokerProtection)
                }
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
        sendNotification(.checkIn, afterDays: 14)
            userDefaults[.didSendCheckedInNotification]  = true
       // }
    }

}

extension DefaultDataBrokerProtectionUserNotificationService: UNUserNotificationCenterDelegate {

    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return .banner
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        switch UNNotificationRequest.Identifier(rawValue: response.notification.request.identifier) {
        case .firstScanComplete, .firstProfileRemoved, .allInfoRemoved, .checkIn:
            if let url = URL(string: "databrokerprotection://opendashboard") {
                NSWorkspace.shared.open(url)
            }
        case .none:
            print("Do nothing")
        }
    }
}

extension UNNotificationRequest {

    enum Identifier: String {
        case firstScanComplete = "dbp.scan.complete"
        case firstProfileRemoved = "dbp.first.removed"
        case allInfoRemoved = "dbp.all.removed"
        case checkIn = "dbp.check-in"
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
        switch self {
        case .firstScanComplete:
            return UNNotificationRequest.Identifier.firstScanComplete.rawValue
        case .firstProfileRemoved:
            return UNNotificationRequest.Identifier.firstProfileRemoved.rawValue
        case .allInfoRemoved:
            return UNNotificationRequest.Identifier.allInfoRemoved.rawValue
        case .checkIn:
            return UNNotificationRequest.Identifier.checkIn.rawValue
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
