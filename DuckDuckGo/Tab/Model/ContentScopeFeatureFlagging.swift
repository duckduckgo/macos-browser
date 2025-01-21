//
//  ContentScopeFeatureFlagging.swift
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

import Foundation
import BrowserServicesKit

extension ContentScopeFeatureToggles {

    static func supportedFeaturesOnMacOS(_ privacyConfig: PrivacyConfiguration) -> ContentScopeFeatureToggles {
        let autofillPrefs = AutofillPreferences()
        return ContentScopeFeatureToggles(emailProtection: true,
                                          emailProtectionIncontextSignup: privacyConfig.isEnabled(featureKey: .incontextSignup),
                                          credentialsAutofill: autofillPrefs.askToSaveUsernamesAndPasswords,
                                          identitiesAutofill: autofillPrefs.askToSaveAddresses,
                                          creditCardsAutofill: autofillPrefs.askToSavePaymentMethods,
                                          credentialsSaving: autofillPrefs.askToSaveUsernamesAndPasswords,
                                          passwordGeneration: autofillPrefs.askToSaveUsernamesAndPasswords,
                                          inlineIconCredentials: autofillPrefs.askToSaveUsernamesAndPasswords,
                                          thirdPartyCredentialsProvider: true,
                                          unknownUsernameCategorization: privacyConfig.isSubfeatureEnabled(AutofillSubfeature.unknownUsernameCategorization),
                                          partialFormSaves: privacyConfig.isSubfeatureEnabled(AutofillSubfeature.partialFormSaves))
    }
}
