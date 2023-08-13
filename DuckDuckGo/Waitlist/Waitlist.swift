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

public protocol WaitlistConstants {
    static var identifier: String { get }
    static var apiProductName: String { get }

    static var notificationIdentifier: String { get }
    static var inviteAvailableNotificationTitle: String { get }
    static var inviteAvailableNotificationBody: String { get }
}

public protocol Waitlist: WaitlistConstants {

    static var shared: Self { get }

    var waitlistStorage: WaitlistStorage { get }
    var waitlistRequest: WaitlistRequest { get }

    init(store: WaitlistStorage, request: WaitlistRequest)

    func fetchInviteCodeIfAvailable() async -> WaitlistInviteCodeFetchError?
    func fetchInviteCodeIfAvailable(completion: @escaping (WaitlistInviteCodeFetchError?) -> Void)
    func sendInviteCodeAvailableNotification()
}

public enum WaitlistInviteCodeFetchError: Error, Equatable {
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
    static let networkProtectionWaitlistShowPopover = Notification.Name(rawValue: "networkProtectionWaitlistShowPopover")

}

public extension Waitlist {

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
                            NotificationCenter.default.post(name: .networkProtectionWaitlistAccessChanged, object: nil)
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

        UNUserNotificationCenter.current().add(request)
    }

}

// MARK: - Extensions

extension Waitlist {

    init() {
        self.init(
            store: WaitlistKeychainStore(waitlistIdentifier: Self.identifier),
            request: ProductWaitlistRequest(productName: Self.apiProductName)
        )
    }

}

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
    static let apiProductName: String = "networkprotection"

    static let shared: NetworkProtectionWaitlist = .init()

    static let notificationIdentifier = "com.duckduckgo.ios.network-protection.invite-code-available"
    static let inviteAvailableNotificationTitle = "Title"
    static let inviteAvailableNotificationBody = "Body"

    let waitlistStorage: WaitlistStorage
    let waitlistRequest: WaitlistRequest

    init(store: WaitlistStorage, request: WaitlistRequest) {
        self.waitlistStorage = store
        self.waitlistRequest = request
    }

}
