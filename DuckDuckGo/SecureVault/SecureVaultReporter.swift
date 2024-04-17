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

final class SecureVaultKeyStoreEventMapper: EventMapping<SecureStorageKeyStoreEvent> {
    public init() {
        super.init { event, _, _, _ in
            switch event {
            case .l1KeyMigration:
                PixelKit.fire(DebugEvent(GeneralPixel.secureVaultKeystoreEventL1KeyMigration))
            case .l2KeyMigration:
                PixelKit.fire(DebugEvent(GeneralPixel.secureVaultKeystoreEventL2KeyMigration))
            case .l2KeyPasswordMigration:
                PixelKit.fire(DebugEvent(GeneralPixel.secureVaultKeystoreEventL2KeyPasswordMigration))
            }
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
            PixelKit.fire(DebugEvent(GeneralPixel.secureVaultInitError(error: error)))
        default:
            PixelKit.fire(DebugEvent(GeneralPixel.secureVaultError(error: error)))
        }
    }

    func secureVaultKeyStoreEvent(_ event: SecureStorageKeyStoreEvent) {
        keyStoreMapper.fire(event)
    }
}
