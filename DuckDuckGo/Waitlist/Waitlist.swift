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

protocol WaitlistConstants {
    static var identifier: String { get }
    static var apiProductName: String { get }

    static var notificationIdentifier: String { get }
    static var inviteAvailableNotificationTitle: String { get }
    static var inviteAvailableNotificationBody: String { get }
}

protocol Waitlist: WaitlistConstants {

    var waitlistStorage: WaitlistStorage { get }
    var waitlistRequest: WaitlistRequest { get }

    func fetchInviteCodeIfAvailable() async -> WaitlistInviteCodeFetchError?
    func fetchInviteCodeIfAvailable(completion: @escaping (WaitlistInviteCodeFetchError?) -> Void)
    func sendInviteCodeAvailableNotification()
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

    func sendInviteCodeAvailableNotification() {
        let notificationContent = UNMutableNotificationContent()

        notificationContent.title = Self.inviteAvailableNotificationTitle
        notificationContent.body = Self.inviteAvailableNotificationBody

        let notificationIdentifier = Self.notificationIdentifier
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: notificationContent, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                DailyPixel.fire(pixel: .networkProtectionWaitlistNotificationShown, frequency: .dailyAndCount, includeAppVersionParameter: true)
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
            store: WaitlistKeychainStore(waitlistIdentifier: Self.identifier),
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
                            // assertionFailure("Failed to redeem invite code")
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
                        sendInviteCodeAvailableNotification()
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
