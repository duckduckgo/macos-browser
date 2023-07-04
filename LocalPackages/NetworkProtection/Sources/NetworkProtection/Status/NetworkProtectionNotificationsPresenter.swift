//
//  NetworkProtectionNotificationsPresenter.swift
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

/// Abstracts the notification presentation.  This was mainly designed for appex vs sysex usage.
///
public protocol NetworkProtectionNotificationsPresenter {

    /// Present a "reconnected" notification to the user.
    func showReconnectedNotification()

    /// Present a "reconnecting" notification to the user.
    func showReconnectingNotification()

    /// Present a "connection failure" notification to the user.
    func showConnectionFailureNotification()

    /// Present a "Superceded by another App" notification to the user.
    func showSupercededNotification()

}
