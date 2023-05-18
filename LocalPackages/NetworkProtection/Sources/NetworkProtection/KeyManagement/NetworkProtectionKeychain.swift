// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Foundation
import Security
import Common

public final class NetworkProtectionKeychain {

    public static func openReference(called ref: Data) -> String? {
        let query: [CFString: Any] = [
            kSecValuePersistentRef: ref,
            kSecReturnData: true
        ]

        var result: CFTypeRef?
        let ret = SecItemCopyMatching(query as CFDictionary, &result)

        if ret != errSecSuccess || result == nil {
            os_log(.error, "🔵 Unable to open config from keychain: %d, %{public}@", ret, query)
            return nil
        }

        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func makeReference(containing value: String, useSystemKeychain: Bool, called name: String, previouslyReferencedBy oldRef: Data? = nil) -> Data? {
        var ret: OSStatus

        guard var bundleIdentifier = Bundle.main.bundleIdentifier else {
            // wg_log(.error, staticMessage: "Unable to determine bundle identifier")
            return nil
        }

        if bundleIdentifier.hasSuffix(".network-extension") {
            bundleIdentifier.removeLast(".network-extension".count)
        }

        let itemLabel = "WireGuard Tunnel: \(name)"
        var items: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                    kSecAttrLabel: itemLabel,
                                    kSecAttrAccount: name + ": " + UUID().uuidString,
                                    kSecAttrDescription: "wg-quick(8) config",
                                    kSecAttrService: bundleIdentifier,
                                    kSecValueData: value.data(using: .utf8) as Any,
                                    kSecReturnPersistentRef: true]

        #if os(iOS)
        items[kSecAttrAccessGroup] = FileManager.appGroupId
        items[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        #elseif os(macOS)
        items[kSecUseDataProtectionKeychain] = !useSystemKeychain
        items[kSecAttrAccessGroup] = "HKE973VLUW.com.duckduckgo.network-protection"
        items[kSecAttrSynchronizable] = false
        items[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #else
        #error("Unimplemented")
        #endif

        var ref: CFTypeRef?
        ret = SecItemAdd(items as CFDictionary, &ref)
        if ret != errSecSuccess || ref == nil {
            // wg_log(.error, message: "Unable to add config to keychain: \(ret)")
            os_log("🔵 SecItemAdd failed: %{public}@", type: .error, String(describing: ret))
            return nil
        }

        if let oldRef = oldRef {
            deleteReference(called: oldRef)
        }

        return ref as? Data
    }

    public static func deleteReference(called ref: Data) {
        let ret = SecItemDelete([kSecValuePersistentRef: ref] as CFDictionary)
        if ret != errSecSuccess {
            // wg_log(.error, message: "Unable to delete config from keychain: \(ret)")
        }
    }

    public static func deleteReferences(except allowlist: Set<Data> = []) {
        var result: CFTypeRef?

        let ret = SecItemCopyMatching([kSecClass: kSecClassGenericPassword,
                                       kSecAttrService: Bundle.main.bundleIdentifier as Any,
                                       kSecMatchLimit: kSecMatchLimitAll,
                                       kSecReturnPersistentRef: true] as CFDictionary,
                                      &result)
        if ret != errSecSuccess || result == nil {
            return
        }

        guard let items = result as? [Data] else { return }

        for item in items where !allowlist.contains(item) {
            deleteReference(called: item)
        }
    }

    public static func verifyReference(called ref: Data) -> Bool {
        return SecItemCopyMatching([kSecValuePersistentRef: ref] as CFDictionary, nil) != errSecItemNotFound
    }

}
