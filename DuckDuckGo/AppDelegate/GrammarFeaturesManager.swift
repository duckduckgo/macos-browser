//
//  GrammarFeaturesManager.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

final class GrammarFeaturesManager {

    // Please see initialize() method of WebView in Source/WebKit/mac/WebView/WebView.mm
    enum Feature {
        case continuousSpellChecking
        case grammarChecking
        case autocorrection

        var webKitPreferenceKeys: [WebKitPreferenceKey] {
            switch self {
            case .continuousSpellChecking: return [.WebContinuousSpellCheckingEnabled]
            case .grammarChecking: return [.WebGrammarCheckingEnabled]
            case .autocorrection: return [
                .WebAutomaticSpellingCorrectionEnabled,
                .WebAutomaticTextReplacementEnabled,
                .WebAutomaticQuoteSubstitutionEnabled,
                .WebAutomaticLinkDetectionEnabled,
                .WebAutomaticDashSubstitutionEnabled
            ]
            }
        }
    }

    // swiftlint:disable identifier_name
    // Please see Source/WebKit/mac/WebView/WebPreferenceKeysPrivate.h for more info
    enum WebKitPreferenceKey: String {
        // Continuous spell checking
        case WebContinuousSpellCheckingEnabled

        // Grammar checking
        case WebGrammarCheckingEnabled

        // Autocorrection
        case WebAutomaticSpellingCorrectionEnabled
        case WebAutomaticTextReplacementEnabled
        case WebAutomaticQuoteSubstitutionEnabled
        case WebAutomaticLinkDetectionEnabled
        case WebAutomaticDashSubstitutionEnabled
    }
    // swiftlint:enable identifier_name

    @UserDefaultsWrapper(key: .spellingCheckEnabledOnce, defaultValue: false)
    var spellingCheckEnabledOnce: Bool

    @UserDefaultsWrapper(key: .grammarCheckEnabledOnce, defaultValue: false)
    var grammarCheckEnabledOnce: Bool

    func manage() {

        func enableFeatureOnce(_ feature: Feature, alreadyEnabledOnce: inout Bool) {
            guard !alreadyEnabledOnce else {
                return
            }

            for key in feature.webKitPreferenceKeys {
                UserDefaults.standard.setValue(true, forKey: key.rawValue)
            }

            alreadyEnabledOnce = true
        }

        func disableFeature(_ feature: Feature) {
            for key in feature.webKitPreferenceKeys {
                UserDefaults.standard.setValue(false, forKey: key.rawValue)
            }
        }

        enableFeatureOnce(.continuousSpellChecking, alreadyEnabledOnce: &spellingCheckEnabledOnce)
        enableFeatureOnce(.grammarChecking, alreadyEnabledOnce: &grammarCheckEnabledOnce)
        disableFeature(.autocorrection)
    }

}
