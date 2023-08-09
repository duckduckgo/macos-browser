//
//  WaitlistViewModel.swift
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

protocol WaitlistViewModelDelegate: AnyObject {
    func dismissModal()
}

public final class WaitlistViewModel: ObservableObject {

    enum ViewState: Equatable {
        case notOnWaitlist
        case joiningWaitlist
        case joinedWaitlist(NotificationPermissionState)
        case invited
        case termsAndConditions
        case readyToEnable
    }

    enum ViewAction: Equatable {
        case joinQueue
        case requestNotificationPermission
        case close
    }

    enum NotificationPermissionState {
        case notDetermined
        case notificationAllowed
        case notificationsDisabled
    }

    @Published var waitlistState: ViewState

    weak var delegate: WaitlistViewModelDelegate?

    private let waitlistRequest: WaitlistRequest
    private let waitlistStorage: WaitlistStorage

    init(waitlistRequest: WaitlistRequest, waitlistStorage: WaitlistStorage) {
        self.waitlistRequest = waitlistRequest
        self.waitlistStorage = waitlistStorage

        // TODO: Determine the real state
        waitlistState = .readyToEnable
    }

    convenience init(waitlist: Waitlist) {
        let waitlistType = type(of: waitlist)
        self.init(
            waitlistRequest: ProductWaitlistRequest(productName: waitlistType.apiProductName),
            waitlistStorage: WaitlistKeychainStore(waitlistIdentifier: waitlistType.identifier)
        )
    }

    func perform(action: ViewAction) {
        switch action {
        case .joinQueue: joinWaitlist()
        case .requestNotificationPermission: requestNotificationPermission()
        case .close: close()
        }
    }

    // MARK: - Action

    private func close() {
        delegate?.dismissModal()
    }

    private func joinWaitlist() {
        waitlistState = .joinedWaitlist(.notDetermined)
    }

    private func requestNotificationPermission() {
        // TODO: Implement
        self.waitlistState = .joinedWaitlist(.notificationAllowed)
    }

}
