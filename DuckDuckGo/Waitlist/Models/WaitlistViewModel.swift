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

final class WaitlistViewModel: ObservableObject {

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
        case closeAndConfirmFeature
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

    weak var delegate: WaitlistViewModelDelegate?

    private let waitlistRequest: WaitlistRequest
    private let waitlistStorage: WaitlistStorage
    private let notificationService: NotificationService
    private var termsAndConditionActionHandler: WaitlistTermsAndConditionsActionHandler
    private let featureSetupHandler: WaitlistFeatureSetupHandler
    private let showNotificationSuccessState: Bool

    init(waitlistRequest: WaitlistRequest,
         waitlistStorage: WaitlistStorage,
         notificationService: NotificationService,
         notificationPermissionState: NotificationPermissionState = .notDetermined,
         showNotificationSuccessState: Bool,
         termsAndConditionActionHandler: WaitlistTermsAndConditionsActionHandler,
         featureSetupHandler: WaitlistFeatureSetupHandler) {
        self.waitlistRequest = waitlistRequest
        self.waitlistStorage = waitlistStorage
        self.notificationService = notificationService
        self.showNotificationSuccessState = showNotificationSuccessState
        self.termsAndConditionActionHandler = termsAndConditionActionHandler
        self.featureSetupHandler = featureSetupHandler
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

    convenience init(waitlist: Waitlist,
                     notificationPermissionState: NotificationPermissionState = .notDetermined,
                     showNotificationSuccessState: Bool,
                     termsAndConditionActionHandler: WaitlistTermsAndConditionsActionHandler,
                     featureSetupHandler: WaitlistFeatureSetupHandler) {
        let waitlistType = type(of: waitlist)
        self.init(
            waitlistRequest: ProductWaitlistRequest(productName: waitlistType.apiProductName),
            waitlistStorage: WaitlistKeychainStore(waitlistIdentifier: waitlistType.identifier, keychainAppGroup: waitlistType.keychainAppGroup),
            notificationService: UNUserNotificationCenter.current(),
            notificationPermissionState: notificationPermissionState,
            showNotificationSuccessState: showNotificationSuccessState,
            termsAndConditionActionHandler: termsAndConditionActionHandler,
            featureSetupHandler: featureSetupHandler
        )
    }

    @MainActor
    func perform(action: ViewAction) async {
        switch action {
        case .joinQueue:
            await joinWaitlist()
        case .requestNotificationPermission:
            requestNotificationPermission()
        case .showTermsAndConditions: showTermsAndConditions()
        case .acceptTermsAndConditions: acceptTermsAndConditions()
        case .close: close()
        case .closeAndConfirmFeature:
            close()
            featureSetupHandler.confirmFeature()
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
    private func requestNotificationPermission() {
        Task {
            do {
                let currentStatus = await notificationService.authorizationStatus()
                let permissionGranted: Bool

                switch currentStatus {
                case .notDetermined:
                    permissionGranted = try await notificationService.requestAuthorization(options: [.alert])
                case .authorized, .provisional:
                    permissionGranted = true
                case .denied:
                    openAppNotificationSettings()
                    permissionGranted = false
                @unknown default:
                    permissionGranted = false
                }
                if permissionGranted {
                     self.viewState = .joinedWaitlist(.notificationAllowed)
                 } else {
                     await perform(action: .close)
                 }
            } catch {
                await checkNotificationPermissions()
            }
        }

        if showNotificationSuccessState {
            self.viewState = .joinedWaitlist(.notificationAllowed)
        } else {
            Task {
                await perform(action: .close)
            }
        }
    }

    private func openAppNotificationSettings() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.duckduckgo"
        let settingsPath = "x-apple.systempreferences:com.apple.preference.notifications"
        let urlComponents = NSURLComponents(string: settingsPath)
        urlComponents?.queryItems = [URLQueryItem(name: "id", value: bundleID)]

        if let appSettings = urlComponents?.url {
            NSWorkspace.shared.open(appSettings)
        }
    }

    private func showTermsAndConditions() {
        viewState = .termsAndConditions
        termsAndConditionActionHandler.didShow()
    }

    private func acceptTermsAndConditions() {
        viewState = .readyToEnable
        termsAndConditionActionHandler.didAccept()
    }
}
