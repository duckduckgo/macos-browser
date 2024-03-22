//
//  DataBrokerProtectionSecureVaultErrorReporter.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit
import SecureStorage
import PixelKit
import Common

final class DataBrokerProtectionSecureVaultErrorReporter: SecureVaultErrorReporting {
    static let shared = DataBrokerProtectionSecureVaultErrorReporter(pixelHandler: DataBrokerProtectionPixelsHandler())

    let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private init(pixelHandler: EventMapping<DataBrokerProtectionPixels>) {
        self.pixelHandler = pixelHandler
    }

    func secureVaultInitFailed(_ error: SecureStorageError) {
        switch error {
        case .initFailed, .failedToOpenDatabase:
            pixelHandler.fire(.secureVaultInitError(error: error))
        default:
            pixelHandler.fire(.secureVaultError(error: error))
        }

        // Also fire the general pixel, since for now all errors are kept under one pixel
        pixelHandler.fire(.generalError(error: error, functionOccurredIn: "secureVaultErrorReporter"))
    }
}
