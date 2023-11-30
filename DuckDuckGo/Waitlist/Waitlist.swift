//
//  Waitlist.swift
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
import Networking
import UserNotifications
import NetworkProtection
import BrowserServicesKit
import Common

protocol WaitlistConstants {
    static var identifier: String { get }
    static var apiProductName: String { get }
    static var keychainAppGroup: String { get }

    static var notificationIdentifier: String { get }
    static var inviteAvailableNotificationTitle: String { get }
    static var inviteAvailableNotificationBody: String { get }
}

protocol Waitlist: WaitlistConstants {

    var waitlistStorage: WaitlistStorage { get }
    var waitlistRequest: WaitlistRequest { get }

    func fetchInviteCodeIfAvailable() async -> WaitlistInviteCodeFetchError?
    func fetchInviteCodeIfAvailable(completion: @escaping (WaitlistInviteCodeFetchError?) -> Void)
    func sendInviteCodeAvailableNotification(completion: (() -> Void)?)
}

enum WaitlistInviteCodeFetchError: Error, Equatable {
    case waitlistInactive
    case alreadyHasInviteCode
    case notOnWaitlist
    case noCodeAvailable
    case failure(Error)

    public static func == (lhs: WaitlistInviteCodeFetchError, rhs: WaitlistInviteCodeFetchError) -> Bool {
        switch (lhs, rhs) {
        case (.alreadyHasInviteCode, .alreadyHasInviteCode): return true
        case (.notOnWaitlist, .notOnWaitlist): return true
        case (.noCodeAvailable, .noCodeAvailable): return true
        default: return false
        }
    }
}

extension Notification.Name {

    static let networkProtectionWaitlistAccessChanged = Notification.Name(rawValue: "networkProtectionWaitlistAccessChanged")
    static let dataBrokerProtectionWaitlistAccessChanged = Notification.Name(rawValue: "dataBrokerProtectionWaitlistAccessChanged")
    static let dataBrokerProtectionUserPressedOnGetStartedOnWaitlist = Notification.Name(rawValue: "dataBrokerProtectionUserPressedOnGetStartedOnWaitlist")

}

extension Waitlist {

    func fetchInviteCodeIfAvailable() async -> WaitlistInviteCodeFetchError? {
        await withCheckedContinuation { continuation in
            fetchInviteCodeIfAvailable { error in
                continuation.resume(returning: error)
            }
        }
    }

    func fetchInviteCodeIfAvailable(completion: @escaping (WaitlistInviteCodeFetchError?) -> Void) {
        guard waitlistStorage.getWaitlistInviteCode() == nil else {
            completion(.alreadyHasInviteCode)
            return
        }

        guard let token = waitlistStorage.getWaitlistToken(), let storedTimestamp = waitlistStorage.getWaitlistTimestamp() else {
            completion(.notOnWaitlist)
            return
        }

        waitlistRequest.getWaitlistStatus { statusResult in
            switch statusResult {
            case .success(let statusResponse):
                if statusResponse.timestamp >= storedTimestamp {
                    waitlistRequest.getInviteCode(token: token) { inviteCodeResult in
                        switch inviteCodeResult {
                        case .success(let inviteCode):
                            waitlistStorage.store(inviteCode: inviteCode.code)
                            completion(nil)
                        case .failure(let inviteCodeError):
                            completion(.failure(inviteCodeError))
                        }

                    }
                } else {
                    // If the user is still in the waitlist, no code is available.
                    completion(.noCodeAvailable)
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func sendInviteCodeAvailableNotification(completion: (() -> Void)?) {
        let notificationContent = UNMutableNotificationContent()

        notificationContent.title = Self.inviteAvailableNotificationTitle
        notificationContent.body = Self.inviteAvailableNotificationBody

        let notificationIdentifier = Self.notificationIdentifier
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: notificationContent, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
               completion?()
            }
        }
    }

}

// MARK: - Extensions

extension ProductWaitlistRequest {

    convenience init(productName: String) {
        let makeHTTPRequest: ProductWaitlistMakeHTTPRequest = { url, method, body, completion in
            guard let httpMethod = APIRequest.HTTPMethod(rawValue: method) else {
                fatalError("The HTTP method is invalid")
            }

            let configuration = APIRequest.Configuration(url: url,
                                                         method: httpMethod,
                                                         body: body)
            let request = APIRequest(configuration: configuration)
            request.fetch { response, error in
                completion(response?.data, error)
            }
        }
        self.init(productName: productName, makeHTTPRequest: makeHTTPRequest)
    }
}

// MARK: - Network Protection Waitlist

struct NetworkProtectionWaitlist: Waitlist {

    static let identifier: String = "networkprotection"
    static let apiProductName: String = "networkprotection_macos"
    static let keychainAppGroup: String = Bundle.main.appGroup(bundle: .netP)

    static let notificationIdentifier = "com.duckduckgo.macos.browser.network-protection.invite-code-available"
    static let inviteAvailableNotificationTitle = UserText.networkProtectionWaitlistNotificationTitle
    static let inviteAvailableNotificationBody = UserText.networkProtectionWaitlistNotificationText

    let waitlistStorage: WaitlistStorage
    let waitlistRequest: WaitlistRequest
    private let networkProtectionCodeRedemption: NetworkProtectionCodeRedeeming

    var shouldShowWaitlistViewController: Bool {
        return isOnWaitlist || readyToAcceptTermsAndConditions
    }

    var isOnWaitlist: Bool {
        return waitlistStorage.isOnWaitlist
    }

    var isInvited: Bool {
        return waitlistStorage.isInvited
    }

    var readyToAcceptTermsAndConditions: Bool {
        let accepted = UserDefaults().bool(forKey: UserDefaultsWrapper<Bool>.Key.networkProtectionTermsAndConditionsAccepted.rawValue)
        return waitlistStorage.isInvited && !accepted
    }

    init() {
        self.init(
            store: WaitlistKeychainStore(waitlistIdentifier: Self.identifier, keychainAppGroup: Self.keychainAppGroup),
            request: ProductWaitlistRequest(productName: Self.apiProductName),
            networkProtectionCodeRedemption: NetworkProtectionCodeRedemptionCoordinator()
        )
    }

    init(store: WaitlistStorage, request: WaitlistRequest, networkProtectionCodeRedemption: NetworkProtectionCodeRedeeming) {
        self.waitlistStorage = store
        self.waitlistRequest = request
        self.networkProtectionCodeRedemption = networkProtectionCodeRedemption
    }

    func fetchNetworkProtectionInviteCodeIfAvailable(completion: @escaping (WaitlistInviteCodeFetchError?) -> Void) {
        self.fetchInviteCodeIfAvailable { error in
            if let error {
                // Check for users who have waitlist state but have no auth token, for example if the redeem call fails.
                let networkProtectionKeyStore = NetworkProtectionKeychainTokenStore()
                if let inviteCode = waitlistStorage.getWaitlistInviteCode(), !networkProtectionKeyStore.isFeatureActivated {
                    Task { @MainActor in
                        do {
                            try await networkProtectionCodeRedemption.redeem(inviteCode)
                            NotificationCenter.default.post(name: .networkProtectionWaitlistAccessChanged, object: nil)
                            completion(nil)
                        } catch {
                            completion(.failure(error))
                        }
                    }
                } else {
                    completion(error)
                }
            } else if let inviteCode = waitlistStorage.getWaitlistInviteCode() {
                Task { @MainActor in
                    do {
                        try await networkProtectionCodeRedemption.redeem(inviteCode)
                        NotificationCenter.default.post(name: .networkProtectionWaitlistAccessChanged, object: nil)
                        sendInviteCodeAvailableNotification {
                            DailyPixel.fire(pixel: .networkProtectionWaitlistNotificationShown, frequency: .dailyAndCount, includeAppVersionParameter: true)
                        }
                        completion(nil)
                    } catch {
                        assertionFailure("Failed to redeem invite code")
                        completion(.failure(error))
                    }
                }
            } else {
                completion(nil)
                assertionFailure("Didn't get error or invite code")
            }
        }
    }

}

#endif

#if DBP

// MARK: - DataBroker Protection Waitlist

import DataBrokerProtection

struct DataBrokerProtectionWaitlist: Waitlist {

    static let identifier: String = "databrokerprotection"
    static let apiProductName: String = "dbp"
    static let keychainAppGroup: String = Bundle.main.appGroup(bundle: .dbp)

    static let notificationIdentifier = "com.duckduckgo.macos.browser.data-broker-protection.invite-code-available"
    static let inviteAvailableNotificationTitle = UserText.dataBrokerProtectionWaitlistNotificationTitle
    static let inviteAvailableNotificationBody = UserText.dataBrokerProtectionWaitlistNotificationText

    let waitlistStorage: WaitlistStorage
    let waitlistRequest: WaitlistRequest

    private let redeemUseCase: DataBrokerProtectionRedeemUseCase
    private let redeemAuthenticationRepository: AuthenticationRepository

    var readyToAcceptTermsAndConditions: Bool {
        let accepted = UserDefaults().bool(forKey: UserDefaultsWrapper<Bool>.Key.dataBrokerProtectionTermsAndConditionsAccepted.rawValue)
        return waitlistStorage.isInvited && !accepted
    }

    init() {
        self.init(
            store: WaitlistKeychainStore(waitlistIdentifier: Self.identifier, keychainAppGroup: Self.keychainAppGroup),
            request: ProductWaitlistRequest(productName: Self.apiProductName),
            redeemUseCase: RedeemUseCase(),
            redeemAuthenticationRepository: KeychainAuthenticationData()
        )
    }

    init(store: WaitlistStorage, request: WaitlistRequest,
         redeemUseCase: DataBrokerProtectionRedeemUseCase,
         redeemAuthenticationRepository: AuthenticationRepository) {
        self.waitlistStorage = store
        self.waitlistRequest = request
        self.redeemUseCase = redeemUseCase
        self.redeemAuthenticationRepository = redeemAuthenticationRepository
    }

    func redeemDataBrokerProtectionInviteCodeIfAvailable() async throws {
        if DefaultDataBrokerProtectionFeatureVisibility.bypassWaitlist {
            return
        }

        do {
            guard waitlistStorage.getWaitlistToken() != nil else {
                os_log("User not in DBP waitlist, returning...", log: .default)
                return
            }

            guard redeemAuthenticationRepository.getAccessToken() == nil else {
                os_log("Invite code already redeemed, returning...", log: .default)
                return
            }

            var inviteCode = waitlistStorage.getWaitlistInviteCode()

            if inviteCode == nil {
                os_log("No DBP invite code found, fetching...", log: .default)
                inviteCode = try await fetchInviteCode()
            }

            if let code = inviteCode {
                try await redeemInviteCode(code)
            } else {
                os_log("No DBP invite code available")
                throw WaitlistInviteCodeFetchError.noCodeAvailable
            }

        } catch {
            os_log("DBP Invite code error: %{public}@", log: .error, error.localizedDescription)
            throw error
        }
    }

    private func fetchInviteCode() async throws -> String {

        // First check if we have it stored locally
        if let inviteCode = waitlistStorage.getWaitlistInviteCode() {
            return inviteCode
        }

        // If not, then try to fetch it remotely
        _ = await fetchInviteCodeIfAvailable()

        // Try to fetch it from storage again
        if let inviteCode = waitlistStorage.getWaitlistInviteCode() {
            return inviteCode
        } else {
            throw WaitlistInviteCodeFetchError.noCodeAvailable
        }
    }

    private func redeemInviteCode(_ inviteCode: String) async throws {
        os_log("Redeeming DBP invite code...", log: .dataBrokerProtection)

        try await redeemUseCase.redeem(inviteCode: inviteCode)
        NotificationCenter.default.post(name: .dataBrokerProtectionWaitlistAccessChanged, object: nil)

        os_log("DBP invite code redeemed", log: .dataBrokerProtection)
        UserDefaults().setValue(true, forKey: UserDefaultsWrapper<Bool>.Key.shouldShowDBPWaitlistInvitedCardUI.rawValue)

        sendInviteCodeAvailableNotification {
            DailyPixel.fire(pixel: .dataBrokerProtectionWaitlistNotificationShown,
                            frequency: .dailyAndCount,
                            includeAppVersionParameter: true)
        }
    }
}

#endif
