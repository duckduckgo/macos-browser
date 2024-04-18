//
//  AutofillActionExecutor.swift
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
import DDGSync
import AppKit
import PixelKit

/// Conforming types provide an `execute` method which performs some action on autofill types (e.g delete all passwords)
protocol AutofillActionExecutor {
    init(userAuthenticator: UserAuthenticating, secureVault: any AutofillSecureVault, syncService: DDGSyncing)
    /// NSAlert to display asking a user to confirm the action
    var confirmationAlert: NSAlert { get }
    /// NSAlert to display when the action is complete
    var completionAlert: NSAlert { get }
    /// Executes the action
    func execute(_ onSuccess: (() -> Void)?)
}

/// Concrete `AutofillActionExecutor` for deletion of all autofill passwords
struct AutofillDeleteAllPasswordsExecutor: AutofillActionExecutor {

    var confirmationAlert: NSAlert {
        let accounts = (try? secureVault.accounts()) ?? []
        return NSAlert.deleteAllPasswordsConfirmationAlert(count: accounts.count, syncEnabled: syncEnabled)
    }

    var completionAlert: NSAlert {
        let accounts = (try? secureVault.accounts()) ?? []
        return NSAlert.deleteAllPasswordsCompletionAlert(count: accounts.count, syncEnabled: syncEnabled)
    }

    private var syncEnabled: Bool {
        syncService.authState != .inactive
    }

    private var userAuthenticator: UserAuthenticating
    private var secureVault: any AutofillSecureVault
    private var syncService: DDGSyncing

    init(userAuthenticator: UserAuthenticating, secureVault: any AutofillSecureVault, syncService: DDGSyncing) {
        self.userAuthenticator = userAuthenticator
        self.secureVault = secureVault
        self.syncService = syncService
    }

    func execute(_ onSuccess: (() -> Void)? = nil) {
        userAuthenticator.authenticateUser(reason: .deleteAllPasswords) { authenticationResult in
            guard authenticationResult.authenticated else { return }

            do {
                try secureVault.deleteAllWebsiteCredentials()
                syncService.scheduler.notifyDataChanged()
                onSuccess?()
            } catch {
                PixelKit.fire(DebugEvent(GeneralPixel.secureVaultError(error: error)))
            }

            return
        }
    }
}
