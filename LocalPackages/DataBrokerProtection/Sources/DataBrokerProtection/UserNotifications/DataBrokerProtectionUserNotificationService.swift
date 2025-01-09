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
import os.log
import PixelKit

public enum DataBrokerProtectionNotificationCommand: String {
    case showDashboard = "databrokerprotection://show_dashboard"

    public var url: URL {
        URL(string: self.rawValue)!
    }
}

public protocol DataBrokerProtectionUserNotificationService {
    func requestNotificationPermission()
    func sendFirstScanCompletedNotification()
    func sendFirstRemovedNotificationIfPossible()
    func sendAllInfoRemovedNotificationIfPossible()
    func scheduleCheckInNotificationIfPossible()
}

// Protocol to enable injection and testing of `DataBrokerProtectionUserNotificationService`
public protocol DBPUserNotificationCenter {
    var delegate: (any UNUserNotificationCenterDelegate)? { get set }
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (((any Error)?) -> Void)?)
    func getNotificationSettings(completionHandler: @escaping (UNNotificationSettings) -> Void)
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, (any Error)?) -> Void)
}

// Conform system `UNUserNotificationCenter` to `DBPUserNotificationCenter` protocol
extension UNUserNotificationCenter: DBPUserNotificationCenter {}

public class DefaultDataBrokerProtectionUserNotificationService: NSObject, DataBrokerProtectionUserNotificationService {
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let userDefaults: UserDefaults
    private var userNotificationCenter: DBPUserNotificationCenter
    private let authenticationManager: DataBrokerProtectionAuthenticationManaging
    private let areNotificationsEnabled = true

    /// The `FreemiumDBPExperimentPixelHandler` instance used to fire pixels
    private let freemiumDBPExperimentPixelHandler: EventMapping<FreemiumDBPExperimentPixel>

    public init(pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                userDefaults: UserDefaults = .standard,
                userNotificationCenter: DBPUserNotificationCenter,
                authenticationManager: DataBrokerProtectionAuthenticationManaging,
                freemiumDBPExperimentPixelHandler: EventMapping<FreemiumDBPExperimentPixel> = FreemiumDBPExperimentPixelHandler()) {
        self.pixelHandler = pixelHandler
        self.userDefaults = userDefaults
        self.userNotificationCenter = userNotificationCenter
        self.authenticationManager = authenticationManager
        self.freemiumDBPExperimentPixelHandler = freemiumDBPExperimentPixelHandler

        super.init()

        self.userNotificationCenter.delegate = self
    }

    public func requestNotificationPermission() {
        guard areNotificationsEnabled else { return }
        requestNotificationPermissionIfNecessary()
    }

    private func sendNotification(_ notification: UserNotification, afterDays days: Int? = nil) {
        requestNotificationPermissionIfNecessary()

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
                Logger.dataBrokerProtection.log("Notification scheduled for an invalid date")
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
                    Logger.dataBrokerProtection.log("Notification scheduled")
                } else {
                    Logger.dataBrokerProtection.log("Notification sent")
                }
            }
        }
    }

    private func requestNotificationPermissionIfNecessary() {
        userNotificationCenter.getNotificationSettings { [weak self] settings in
            if settings.authorizationStatus == .notDetermined {
                self?.userNotificationCenter.requestAuthorization(options: [.alert]) { _, _ in }
            }
        }
    }

    public func sendFirstScanCompletedNotification() {
        guard areNotificationsEnabled else { return }

        // If the user is not authenticated, this is a Freemium scan
        if !authenticationManager.isUserAuthenticated {
            sendNotification(.firstFreemiumScanComplete)
            freemiumDBPExperimentPixelHandler.fire(FreemiumDBPExperimentPixel.firstScanCompleteNotificationSent)
        } else {
            sendNotification(.firstScanComplete)
            pixelHandler.fire(.dataBrokerProtectionNotificationSentFirstScanComplete)
        }
    }

    public func sendFirstRemovedNotificationIfPossible() {
        guard areNotificationsEnabled else { return }

        if userDefaults[.didSendFirstRemovedNotification] != true {
            sendNotification(.firstProfileRemoved)
            userDefaults[.didSendFirstRemovedNotification]  = true

            pixelHandler.fire(.dataBrokerProtectionNotificationSentFirstRemoval)
        }
    }

    public func sendAllInfoRemovedNotificationIfPossible() {
        guard areNotificationsEnabled else { return }

        if userDefaults[.didSendAllInfoRemovedNotification] != true {
            sendNotification(.allInfoRemoved)
            userDefaults[.didSendAllInfoRemovedNotification]  = true

            pixelHandler.fire(.dataBrokerProtectionNotificationSentAllRecordsRemoved)
        }
    }

    public func scheduleCheckInNotificationIfPossible() {
        guard areNotificationsEnabled else { return }

        if userDefaults[.didSendCheckedInNotification] != true {
            sendNotification(.twoWeeksCheckIn, afterDays: 14)
            userDefaults[.didSendCheckedInNotification]  = true

            pixelHandler.fire(.dataBrokerProtectionNotificationScheduled2WeeksCheckIn)
        }
    }

}

extension DefaultDataBrokerProtectionUserNotificationService: UNUserNotificationCenterDelegate {

    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return .banner
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let identifier = UNNotificationRequest.Identifier(rawValue: response.notification.request.identifier) else { return }

        let pixelMapper: [UNNotificationRequest.Identifier: DataBrokerProtectionPixels] = [.firstScanComplete: .dataBrokerProtectionNotificationOpenedFirstScanComplete,
                                                                                           .firstProfileRemoved: .dataBrokerProtectionNotificationOpenedFirstRemoval,
                                                                                           .allInfoRemoved: .dataBrokerProtectionNotificationOpenedAllRecordsRemoved,
                                                                                           .twoWeeksCheckIn: .dataBrokerProtectionNotificationOpened2WeeksCheckIn]

        switch identifier {
        case .firstScanComplete, .firstProfileRemoved, .allInfoRemoved, .twoWeeksCheckIn:
            NSWorkspace.shared.open(DataBrokerProtectionNotificationCommand.showDashboard.url)

            if let pixel = pixelMapper[identifier] {
                pixelHandler.fire(pixel)
            }
        case .firstFreemiumScanComplete:
            NSWorkspace.shared.open(DataBrokerProtectionNotificationCommand.showDashboard.url)

            freemiumDBPExperimentPixelHandler.fire(FreemiumDBPExperimentPixel.firstScanCompleteNotificationClicked)
        }
    }
}

extension UNNotificationRequest {

    enum Identifier: String {
        case firstFreemiumScanComplete = "dbp.freemium.scan.complete"
        case firstScanComplete = "dbp.scan.complete"
        case firstProfileRemoved = "dbp.first.removed"
        case allInfoRemoved = "dbp.all.removed"
        case twoWeeksCheckIn = "dbp.2-weeks-check-in"
    }
}

private enum UserNotification {
    case firstFreemiumScanComplete
    case firstScanComplete
    case firstProfileRemoved
    case allInfoRemoved
    case twoWeeksCheckIn

    var title: String {
        switch self {
        case .firstFreemiumScanComplete:
            return "Free Personal Information Scan"
        case .firstScanComplete:
            return "Scan complete!"
        case .firstProfileRemoved:
            return "A record of your info was removed!"
        case .allInfoRemoved:
            return "Personal info removed!"
        case .twoWeeksCheckIn:
            return "We're making progress!"
        }
    }

    var message: String {
        switch self {
        case .firstFreemiumScanComplete:
            return "Your free personal info scan is now complete. Check out the results..."
        case .firstScanComplete:
            return "DuckDuckGo has started the process to remove records matching your personal info online. See what we found..."
        case .firstProfileRemoved:
            return "That’s one less creepy site storing and selling your personal info online. Check progress..."
        case .allInfoRemoved:
            return "See all the records matching your personal info that DuckDuckGo found and removed from the web..."
        case .twoWeeksCheckIn:
            return "See the records matching your personal info that DuckDuckGo found and removed from the web so far..."
        }
    }

    var identifier: String {
        switch self {
        case .firstFreemiumScanComplete:
            return UNNotificationRequest.Identifier.firstFreemiumScanComplete.rawValue
        case .firstScanComplete:
            return UNNotificationRequest.Identifier.firstScanComplete.rawValue
        case .firstProfileRemoved:
            return UNNotificationRequest.Identifier.firstProfileRemoved.rawValue
        case .allInfoRemoved:
            return UNNotificationRequest.Identifier.allInfoRemoved.rawValue
        case .twoWeeksCheckIn:
            return UNNotificationRequest.Identifier.twoWeeksCheckIn.rawValue
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
