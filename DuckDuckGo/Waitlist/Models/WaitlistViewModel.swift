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

#if NETWORK_PROTECTION

import Foundation
import NetworkProtection
import UserNotifications

protocol WaitlistViewModelDelegate: AnyObject {
    func dismissModal()
    func viewHeightChanged(newHeight: CGFloat)
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
        case showTermsAndConditions
        case acceptTermsAndConditions
        case close
        case closeAndPinNetworkProtection
    }

    enum NotificationPermissionState {
        case notDetermined
        case notificationAllowed
        case notificationsDisabled

        static func from(_ status: UNAuthorizationStatus) -> NotificationPermissionState {
            switch status {
            case .notDetermined: return .notDetermined
            case .denied: return .notificationsDisabled
            default: return .notificationAllowed
            }
        }
    }

    @Published var viewState: ViewState

    @UserDefaultsWrapper(key: .networkProtectionTermsAndConditionsAccepted, defaultValue: false)
    var acceptedNetworkProtectionTermsAndConditions: Bool

    weak var delegate: WaitlistViewModelDelegate?

    private let waitlistRequest: WaitlistRequest
    private let waitlistStorage: WaitlistStorage
    private let notificationService: NotificationService

    init(waitlistRequest: WaitlistRequest,
         waitlistStorage: WaitlistStorage,
         notificationService: NotificationService,
         notificationPermissionState: NotificationPermissionState = .notDetermined) {
        self.waitlistRequest = waitlistRequest
        self.waitlistStorage = waitlistStorage
        self.notificationService = notificationService

        if waitlistStorage.getWaitlistTimestamp() != nil, waitlistStorage.getWaitlistInviteCode() == nil {
            viewState = .joinedWaitlist(notificationPermissionState)

            Task { @MainActor in
                await checkNotificationPermissions()
            }
        } else if waitlistStorage.getWaitlistInviteCode() != nil {
            viewState = .invited
        } else {
            viewState = .notOnWaitlist
        }
    }

    convenience init(waitlist: Waitlist, notificationPermissionState: NotificationPermissionState = .notDetermined) {
        let waitlistType = type(of: waitlist)
        self.init(
            waitlistRequest: ProductWaitlistRequest(productName: waitlistType.apiProductName),
            waitlistStorage: WaitlistKeychainStore(waitlistIdentifier: waitlistType.identifier),
            notificationService: UNUserNotificationCenter.current(),
            notificationPermissionState: notificationPermissionState
        )
    }

    @MainActor
    func perform(action: ViewAction) async {
        switch action {
        case .joinQueue: await joinWaitlist()
        case .requestNotificationPermission:
            Task {
                await requestNotificationPermission()
            }
        case .showTermsAndConditions: showTermsAndConditions()
        case .acceptTermsAndConditions: acceptTermsAndConditions()
        case .close: close()
        case .closeAndPinNetworkProtection:
            close()

            LocalPinningManager.shared.pin(.networkProtection)
            NotificationCenter.default.post(name: .networkProtectionWaitlistAccessChanged, object: nil)
        }
    }

    public func updateViewState() async {
        if waitlistStorage.getWaitlistTimestamp() != nil, waitlistStorage.getWaitlistInviteCode() == nil {
            await checkNotificationPermissions()
        } else if waitlistStorage.getWaitlistInviteCode() != nil {
            self.viewState = .invited
        } else {
            self.viewState = .notOnWaitlist
        }
    }

    func receivedNewViewHeight(_ height: CGFloat) {
        self.delegate?.viewHeightChanged(newHeight: height)
    }

    @MainActor
    private func checkNotificationPermissions() async {
        let status = await notificationService.authorizationStatus()
        viewState = .joinedWaitlist(NotificationPermissionState.from(status))
    }

    // MARK: - Action

    private func close() {
        delegate?.dismissModal()
    }

    @MainActor
    private func joinWaitlist() async {
        self.viewState = .joiningWaitlist

        let waitlistJoinResult = await waitlistRequest.joinWaitlist()

        switch waitlistJoinResult {
        case .success(let joinResponse):
            waitlistStorage.store(waitlistToken: joinResponse.token)
            waitlistStorage.store(waitlistTimestamp: joinResponse.timestamp)
            await checkNotificationPermissions()
        case .failure:
            self.viewState = .notOnWaitlist
        }
    }

    @MainActor
    private func requestNotificationPermission() async {
        do {
            let permissionGranted = try await notificationService.requestAuthorization(options: [.alert])

            if permissionGranted {
                self.viewState = .joinedWaitlist(.notificationAllowed)
            } else {
                self.viewState = .joinedWaitlist(.notificationsDisabled)
            }
        } catch {
            await checkNotificationPermissions()
        }
    }

    private func showTermsAndConditions() {
        viewState = .termsAndConditions

        DailyPixel.fire(pixel: .networkProtectionWaitlistTermsAndConditionsDisplayed, frequency: .dailyAndCount, includeAppVersionParameter: true)
    }

    private func acceptTermsAndConditions() {
        acceptedNetworkProtectionTermsAndConditions = true
        viewState = .readyToEnable

        // Remove delivered NetP notifications in case the user didn't click them.
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [NetworkProtectionWaitlist.notificationIdentifier])

        DailyPixel.fire(pixel: .networkProtectionWaitlistTermsAndConditionsAccepted, frequency: .dailyAndCount, includeAppVersionParameter: true)
    }

}

#endif
