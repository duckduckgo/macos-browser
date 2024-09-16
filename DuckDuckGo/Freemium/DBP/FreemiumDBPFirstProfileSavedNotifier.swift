//
//  FreemiumDBPFirstProfileSavedNotifier.swift
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

import Foundation
import Freemium
import DataBrokerProtection
import Subscription
import OSLog

/// A concrete implementation of the `DBPProfileSavedNotifier` protocol that handles posting the "Profile Saved" notification
/// for Freemium users based on their Freemium activation state, authentication state, and if this is their first saved profile. This class ensures the notification is posted only once.
final class FreemiumDBPFirstProfileSavedNotifier: DBPProfileSavedNotifier {

    private var freemiumDBPUserStateManager: FreemiumDBPUserStateManager
    private var accountManager: AccountManager
    private let notificationCenter: NotificationCenter

    /// Initializes the notifier with the necessary dependencies to check user state and post notifications.
    ///
    /// - Parameters:
    ///   - freemiumDBPUserStateManager: Manages the user state related to Freemium DBP.
    ///   - accountManager: Manages account-related information, such as whether the user is authenticated.
    ///   - notificationCenter: The notification center for posting notifications. Defaults to the system's default notification center.
    init(freemiumDBPUserStateManager: FreemiumDBPUserStateManager, accountManager: AccountManager, notificationCenter: NotificationCenter = .default) {
        self.freemiumDBPUserStateManager = freemiumDBPUserStateManager
        self.accountManager = accountManager
        self.notificationCenter = notificationCenter
    }

    /// Posts the "Profile Saved" notification if the following conditions are met:
    /// - The user is not authenticated
    /// - The user has activated Freemium (i.e accessed the feature).
    /// - The "Profile Saved" notification has not already been posted.
    ///
    /// If all conditions are met, the method posts a `pirProfileSaved` notification via the `NotificationCenter` and records that the notification has been posted.
    func postProfileSavedNotificationIfPermitted() {
        guard !accountManager.isUserAuthenticated
                && freemiumDBPUserStateManager.didActivate
                && !freemiumDBPUserStateManager.didPostFirstProfileSavedNotification else { return }

        Logger.freemiumDBP.debug("[Freemium DBP] Posting Profile Saved Notification")
        notificationCenter.post(name: .pirProfileSaved, object: nil)

        freemiumDBPUserStateManager.didPostFirstProfileSavedNotification = true
    }
}
