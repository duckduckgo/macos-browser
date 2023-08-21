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
        case acceptingTermsAndConditions
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
    private let networkProtectionCodeRedemption: NetworkProtectionCodeRedeeming

    init(waitlistRequest: WaitlistRequest,
         waitlistStorage: WaitlistStorage,
         notificationService: NotificationService,
         networkProtectionCodeRedemption: NetworkProtectionCodeRedeeming) {
        self.waitlistRequest = waitlistRequest
        self.waitlistStorage = waitlistStorage
        self.notificationService = notificationService
        self.networkProtectionCodeRedemption = networkProtectionCodeRedemption

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
            notificationService: UNUserNotificationCenter.current(),
            networkProtectionCodeRedemption: NetworkProtectionCodeRedemptionCoordinator()
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
        case .acceptTermsAndConditions: await acceptTermsAndConditions()
        case .close: close()
        case .closeAndPresentNetworkProtectionPopover:
            close()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .networkProtectionWaitlistShowPopover, object: nil)
            }
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

    @MainActor
    private func acceptTermsAndConditions() async {
        guard let inviteCode = waitlistStorage.getWaitlistInviteCode() else {
            assertionFailure("Got into terms & conditions state without having an invite code")
            return
        }

        self.viewState = .acceptingTermsAndConditions

        do {
            try await networkProtectionCodeRedemption.redeem(inviteCode)

            acceptedNetworkProtectionTermsAndConditions = true
            viewState = .readyToEnable
        } catch {
            viewState = .termsAndConditions
        }
    }

}
