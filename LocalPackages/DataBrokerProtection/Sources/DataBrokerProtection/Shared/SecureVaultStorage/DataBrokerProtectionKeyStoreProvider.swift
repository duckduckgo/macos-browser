//
//  DataBrokerProtectionKeyStoreProvider.swift
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

import Common
import Foundation
import BrowserServicesKit
import SecureStorage
import os.log

final class DataBrokerProtectionKeyStoreProvider: SecureStorageKeyStoreProvider {

    struct Constants {
        static let defaultServiceName = "DataBrokerProtection DuckDuckGo Secure Vault"
    }

    // DO NOT CHANGE except if you want to deliberately invalidate all users's vaults.
    // The keys have a uid to deter casual hacker from easily seeing which keychain entry is related to what.
    enum EntryName: String, CaseIterable {
        case generatedPassword = "5FCE971A-DE67-4649-9A42-5E6DAB026E72"
        case l1Key = "9CA59EDC-5CE8-4F53-AAC6-286A7378F384"
        case l2Key = "E544DC56-1D72-4C5D-9738-FDFA6602C47E"
    }

    var generatedPasswordEntryName: String {
        return EntryName.generatedPassword.rawValue
    }

    var l1KeyEntryName: String {
        return EntryName.l1Key.rawValue
    }

    var l2KeyEntryName: String {
        return EntryName.l2Key.rawValue
    }

    var keychainServiceName: String {
        return Constants.defaultServiceName
    }

    var keychainAccessibilityValue: String {
        kSecAttrAccessibleAfterFirstUnlock as String
    }

    let keychainService: KeychainService
    private let groupNameProvider: GroupNameProviding

    init(keychainService: KeychainService = DefaultKeychainService(),
         groupNameProvider: GroupNameProviding = Bundle.main) {
        self.keychainService = keychainService
        self.groupNameProvider = groupNameProvider
    }

    func readData(named: String, serviceName: String) throws -> Data? {
        try readOrMigrate(named: named, serviceName: serviceName)
    }

    func attributesForEntry(named: String, serviceName: String) -> [String: Any] {
        [
           kSecClass: kSecClassGenericPassword,
           kSecUseDataProtectionKeychain: true,
           kSecAttrSynchronizable: false,
           kSecAttrAccessGroup: groupNameProvider.appGroupName,
           kSecAttrAccount: named,
       ] as [String: Any]
    }
}

private extension DataBrokerProtectionKeyStoreProvider {

    var afterFirstUnlockAttributeUpdate: [String: Any] {
        [kSecAttrAccessible as String: keychainAccessibilityValue]
    }

    /// Reads data from the Keychain using the latest query attributes, or if not found, reads using old query attributes and if found, migrates
    /// - Parameters:
    ///   - name: Keychain item name
    ///   - serviceName: Keychain service name
    /// - Returns: Optional Data
    func readOrMigrate(named name: String, serviceName: String) throws -> Data? {

        // Try to read keychain data using attributes which include `kSecAttrAccessible` value of `kSecAttrAccessibleAfterFirstUnlock`
        let attributes = afterFirstUnlockQueryAttributes(named: name, serviceName: serviceName)

        if let data = try read(serviceName: serviceName, queryAttributes: attributes) {
            return data
        } else {

            // If we didn't find Keychain data, try using attributes WITHOUT `kSecAttrAccessible` value of `kSecAttrAccessibleAfterFirstUnlock`
            let legacyAttributes = whenUnlockedQueryAttributes(named: name, serviceName: serviceName)

            let accessibilityValueString = legacyAttributes[kSecAttrAccessible as String] as? String ?? "[value unavailable]"
            Logger.dataBrokerProtection.log("Attempting read and migrate of DBP Keychain data with kSecAttrAccessible value of \(accessibilityValueString)")

            if let data = try read(serviceName: serviceName, queryAttributes: legacyAttributes) {
                // We found Keychain data, so update it's `kSecAttrAccessible` value to `kSecAttrAccessibleAfterFirstUnlock`
                try update(serviceName: serviceName, queryAttributes: legacyAttributes, attributeUpdate: afterFirstUnlockAttributeUpdate)
                return data
            }
        }

        return nil
    }

    /// Reads a Keychain item
    /// - Parameters:
    ///   - serviceName: Keychain service name
    ///   - queryAttributes: Attributes used to query the item
    /// - Returns: Optional Data
    func read(serviceName: String, queryAttributes: [String: Any]) throws -> Data? {
        var query = queryAttributes
        query[kSecReturnData as String] = true
        query[kSecAttrService as String] = serviceName

        var item: CFTypeRef?

        let status = keychainService.itemMatching(query, &item)

        switch status {

        case errSecSuccess:
            guard let itemData = item as? Data,
                  let itemString = String(data: itemData, encoding: .utf8),
                  let decodedData = Data(base64Encoded: itemString) else {
                throw SecureStorageError.keystoreError(status: status)
            }
            return decodedData

        case errSecItemNotFound:
            return nil

        default:
            throw SecureStorageError.keystoreReadError(status: status)
        }
    }

    /// Updates a Keychain item
    /// - Parameters:
    ///   - serviceName: Keychain service name
    ///   - queryAttributes: Attributes used to query the item
    ///   - attributeUpdate: Attribute updates
    func update(serviceName: String, queryAttributes: [String: Any], attributeUpdate: [String: Any]) throws {
        var query = queryAttributes
        query[kSecAttrService as String] = serviceName

        let status = keychainService.update(queryAttributes, attributeUpdate)

        guard status == errSecSuccess else {
            throw SecureStorageError.keystoreUpdateError(status: status)
        }

        let accessibilityValueString = attributeUpdate[kSecAttrAccessible as String] as? String ?? "[value unavailable]"
        Logger.dataBrokerProtection.log("Updated DBP Keychain data kSecAttrAccessible value to \(accessibilityValueString)")
    }

    func afterFirstUnlockQueryAttributes(named name: String, serviceName: String) -> [String: Any] {
        var attributes = attributesForEntry(named: name, serviceName: serviceName)
        attributes[kSecAttrAccessible as String] = keychainAccessibilityValue
        return attributes
    }

    func whenUnlockedQueryAttributes(named name: String, serviceName: String) -> [String: Any] {
        var attributes = attributesForEntry(named: name, serviceName: serviceName)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        return attributes
    }
}
