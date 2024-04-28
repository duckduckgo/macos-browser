//
//  MockAutofillActionExecutor.swift
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
import DDGSync
import Foundation
@testable import DuckDuckGo_Privacy_Browser

final class MockAutofillActionBuilder: AutofillActionBuilder {

    var mockExecutor: MockAutofillActionExecutor?
    var mockPresenter: MockAutofillActionPresenter?

    func buildExecutor() -> AutofillActionExecutor? {
        guard let secureVault = try? MockSecureVaultFactory.makeVault(reporter: nil) else { return nil }
        let syncService = MockDDGSyncing(authState: .inactive, scheduler: CapturingScheduler(), isSyncInProgress: false)
        let executor = MockAutofillActionExecutor(userAuthenticator: UserAuthenticatorMock(), secureVault: secureVault, syncService: syncService)
        self.mockExecutor = executor
        return executor
    }

    func buildPresenter() -> AutofillActionPresenter {
        let presenter = MockAutofillActionPresenter()
        self.mockPresenter = presenter
        return presenter
    }
}

final class MockAutofillActionExecutor: AutofillActionExecutor {

    var didExecute = false

    init(userAuthenticator: UserAuthenticating, secureVault: any AutofillSecureVault, syncService: DDGSyncing) { }

    var confirmationAlert: NSAlert {
        NSAlert()
    }

    var completionAlert: NSAlert {
        NSAlert()
    }

    func execute(_ onSuccess: (() -> Void)?) {
        didExecute = true
    }
}
