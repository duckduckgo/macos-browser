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
        case closeAndPresentNetworkProtectionPopover
    }

    enum NotificationPermissionState {
        case notDetermined
        case notificationAllowed
        case notificationsDisabled
    }

    @Published var viewState: ViewState

    @UserDefaultsWrapper(key: .networkProtectionTermsAndConditionsAccepted, defaultValue: false)
    var acceptedNetworkProtectionTermsAndConditions: Bool

    weak var delegate: WaitlistViewModelDelegate?

    private let waitlistRequest: WaitlistRequest
    private let waitlistStorage: WaitlistStorage
    private let notificationService: NotificationService

    init(waitlistRequest: WaitlistRequest, waitlistStorage: WaitlistStorage, notificationService: NotificationService) {
        self.waitlistRequest = waitlistRequest
        self.waitlistStorage = waitlistStorage
        self.notificationService = notificationService

        if waitlistStorage.getWaitlistTimestamp() != nil, waitlistStorage.getWaitlistInviteCode() == nil {
            viewState = .joinedWaitlist(.notDetermined)

            Task {
                await checkNotificationPermissions()
            }
        } else if waitlistStorage.getWaitlistInviteCode() != nil {
            viewState = .invited
        } else {
            viewState = .notOnWaitlist
        }
    }

    convenience init(waitlist: Waitlist) {
        let waitlistType = type(of: waitlist)
        self.init(
            waitlistRequest: ProductWaitlistRequest(productName: waitlistType.apiProductName),
            waitlistStorage: WaitlistKeychainStore(waitlistIdentifier: waitlistType.identifier),
            notificationService: UNUserNotificationCenter.current()
        )
    }

    func perform(action: ViewAction) {
        switch action {
        case .joinQueue: joinWaitlist()
        case .requestNotificationPermission:
            Task {
                await requestNotificationPermission()
            }
        case .showTermsAndConditions: showTermsAndConditions()
        case .acceptTermsAndConditions: acceptTermsAndConditions()
        case .close: close()
        case .closeAndPresentNetworkProtectionPopover:
            close()

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .networkProtectionWaitlistShowPopover, object: nil)
            }
        }
    }

    func receivedNewViewHeight(_ height: CGFloat) {
        self.delegate?.viewHeightChanged(newHeight: height)
    }

    @MainActor
    private func checkNotificationPermissions() async {
        switch await notificationService.authorizationStatus() {
        case .notDetermined:
            viewState = .joinedWaitlist(.notDetermined)
        case .denied:
            viewState = .joinedWaitlist(.notificationsDisabled)
        default:
            viewState = .joinedWaitlist(.notificationAllowed)
        }
    }

    // MARK: - Action

    private func close() {
        delegate?.dismissModal()
    }

    private func joinWaitlist() {
        self.viewState = .joiningWaitlist

        Task {
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
    }

    private func requestNotificationPermission() async {
        do {
            let permissionGranted = try await notificationService.requestAuthorization(options: [.alert]) == true

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
    }

    private func acceptTermsAndConditions() {
        acceptedNetworkProtectionTermsAndConditions = true
        viewState = .readyToEnable
    }

}
