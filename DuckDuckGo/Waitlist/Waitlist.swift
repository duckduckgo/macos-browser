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

import Foundation
import Networking
import UserNotifications
import NetworkProtection
import BrowserServicesKit
import Common
import Subscription

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
            DispatchQueue.main.async {
                DataBrokerProtectionExternalWaitlistPixels.fire(pixel: GeneralPixel.dataBrokerProtectionWaitlistNotificationShown, frequency: .dailyAndCount)
            }
        }
    }
}

#endif
