//
//  AutofillActionBuilder.swift
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

import BrowserServicesKit
import Foundation

/// Conforming types provide methods to build an `AutofillActionExecutor` and an `AutofillActionPresenter`
protocol AutofillActionBuilder {
    func buildExecutor() -> AutofillActionExecutor?
    func buildPresenter() -> AutofillActionPresenter
}

extension AutofillActionBuilder {
    func buildPresenter() -> AutofillActionPresenter {
        DefaultAutofillActionPresenter()
    }
}

/// Builds an `AutofillActionExecutor`
struct AutofillDeleteAllPasswordsBuilder: AutofillActionBuilder {
    @MainActor
    func buildExecutor() -> AutofillActionExecutor? {
        guard let secureVault = try? AutofillSecureVaultFactory.makeVault(reporter: SecureVaultReporter.shared),
        let syncService = NSApp.delegateTyped.syncService else { return nil }

        return AutofillDeleteAllPasswordsExecutor(userAuthenticator: DeviceAuthenticator.shared,
                                                  secureVault: secureVault,
                                                  syncService: syncService)
    }
}
