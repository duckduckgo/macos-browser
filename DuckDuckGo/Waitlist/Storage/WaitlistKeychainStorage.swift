//
//  WaitlistKeychainStorage.swift
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

final class WaitlistKeychainStore: WaitlistStorage {

    static let inviteCodeDidChangeNotification = Notification.Name("com.duckduckgo.app.waitlist.invite-code-changed")

    enum WaitlistKeychainField: String {
        case waitlistToken = "token"
        case waitlistTimestamp = "timestamp"
        case inviteCode = "invite-code"
    }

    init(waitlistIdentifier: String, keychainPrefix: String? = Bundle.main.bundleIdentifier, keychainAppGroup: String) {
        self.waitlistIdentifier = waitlistIdentifier
        self.keychainPrefix = keychainPrefix ?? "com.duckduckgo"
        self.keychainAppGroup = keychainAppGroup
    }

    func getWaitlistToken() -> String? {
        return getString(forField: .waitlistToken)
    }

    func getWaitlistTimestamp() -> Int? {
        guard let timestampString = getString(forField: .waitlistTimestamp) else { return nil }
        return Int(timestampString)
    }

    func getWaitlistInviteCode() -> String? {
        return getString(forField: .inviteCode)
    }

    func store(waitlistToken: String) {
        add(string: waitlistToken, forField: .waitlistToken)
    }

    func store(waitlistTimestamp: Int) {
        let timestampString = String(waitlistTimestamp)
        add(string: timestampString, forField: .waitlistTimestamp)
    }

    func store(inviteCode: String) {
        add(string: inviteCode, forField: .inviteCode)
        NotificationCenter.default.post(name: Self.inviteCodeDidChangeNotification, object: waitlistIdentifier)
    }

    func deleteWaitlistState() {
        deleteItem(forField: .waitlistToken)
        deleteItem(forField: .waitlistTimestamp)
        deleteItem(forField: .inviteCode)
    }

    func delete(field: WaitlistKeychainField) {
        deleteItem(forField: field)
    }

    // MARK: - Keychain Read

    private func getString(forField field: WaitlistKeychainField) -> String? {
        guard let data = retrieveData(forField: field),
              let string = String(data: data, encoding: String.Encoding.utf8) else {
            return nil
        }
        return string
    }

    private func retrieveData(forField field: WaitlistKeychainField) -> Data? {
        var query = defaultAttributes(serviceName: keychainServiceName(for: field))
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let existingItem = item as? Data else {
            return nil
        }

        return existingItem
    }

    // MARK: - Keychain Write

    private func add(string: String, forField field: WaitlistKeychainField) {
        guard let stringData = string.data(using: .utf8) else {
            return
        }

        deleteItem(forField: field)
        add(data: stringData, forField: field)
    }

    private func add(data: Data, forField field: WaitlistKeychainField) {
        var query = defaultAttributes(serviceName: keychainServiceName(for: field))
        query[kSecValueData as String] = data
        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteItem(forField field: WaitlistKeychainField) {
        let query = defaultAttributes(serviceName: keychainServiceName(for: field))
        SecItemDelete(query as CFDictionary)
    }

    // MARK: -

    private func defaultAttributes(serviceName: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrSynchronizable as String: false,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrAccessGroup as String: keychainAppGroup,
            kSecAttrService as String: serviceName,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
    }

    func keychainServiceName(for field: WaitlistKeychainField) -> String {
        [keychainPrefix, "waitlist", waitlistIdentifier, field.rawValue].joined(separator: ".")
    }

    private let waitlistIdentifier: String
    private let keychainPrefix: String
    private let keychainAppGroup: String
}
