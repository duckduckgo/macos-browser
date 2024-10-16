//
//  AutofillPixelEvent.swift
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
import PixelKit

enum AutofillPixelKitEvent: PixelKitEventV2 {
    case importCredentialsFlowStarted
    case importCredentialsFlowCancelled
    case importCredentialsFlowHadCredentials
    case importCredentialsFlowEnded

    case importCredentialsPromptNeverAgainClicked

    var name: String {
        switch self {
        case .importCredentialsFlowStarted: "autofill_import_credentials_flow_started"
        case .importCredentialsFlowCancelled: "autofill_import_credentials_flow_cancelled"
        case .importCredentialsFlowHadCredentials: "autofill_import_credentials_flow_had_credentials"
        case .importCredentialsFlowEnded: "autofill_import_credentials_flow_ended"
        case .importCredentialsPromptNeverAgainClicked: "autofill_import_credentials_prompt_never_again_clicked"
        }
    }

    var parameters: [String: String]? {
        nil
    }

    var error: (any Error)? {
        nil
    }

    var withoutMacPrefix: NonStandardEvent {
        NonStandardEvent(self)
    }
}
