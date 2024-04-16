//
//  SecureVaultReporter.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import PixelKit
import SecureStorage

extension SecureStorageKeyStoreEvent: PixelKitEvent {
    public var name: String {
        switch self {
        case .l1KeyMigration: return "m_mac_secure_vault_keystore_event_l1-key-migration"
        case .l2KeyMigration: return "m_mac_secure_vault_keystore_event_l2-key-migration"
        case .l2KeyPasswordMigration: return "m_mac_secure_vault_keystore_event_l2-key-password-migration"
        }
    }

    public var parameters: [String: String]? {
        nil
    }
}

final class SecureVaultKeyStoreEventMapper: EventMapping<SecureStorageKeyStoreEvent> {
    public init() {
        super.init { event, _, _, _ in
            PixelKit.fire(DebugEvent(event))
        }
    }

    override init(mapping: @escaping EventMapping<SecureStorageKeyStoreEvent>.Mapping) {
        fatalError("Use init()")
    }
}

final class SecureVaultReporter: SecureVaultReporting {
    static let shared = SecureVaultReporter()
    private var keyStoreMapper: SecureVaultKeyStoreEventMapper
    private init(keyStoreMapper: SecureVaultKeyStoreEventMapper = SecureVaultKeyStoreEventMapper()) {
        self.keyStoreMapper = keyStoreMapper
    }

    func secureVaultError(_ error: SecureStorageError) {
        guard NSApp.runType.requiresEnvironment else { return }

        switch error {
        case .initFailed, .failedToOpenDatabase:
            Pixel.fire(.debug(event: .secureVaultInitError, error: error))
        default:
            Pixel.fire(.debug(event: .secureVaultError, error: error))
        }
    }

    func secureVaultKeyStoreEvent(_ event: SecureStorageKeyStoreEvent) {
        keyStoreMapper.fire(event)
    }
}
