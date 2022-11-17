//
//  WKWebViewConfigurationExtensions.swift
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

import WebKit
import Combine
import BrowserServicesKit

extension WKWebViewConfiguration {

    struct Dependencies {
        @Injected(.testable) static var privatePlayerSchemeHandler: WKURLSchemeHandler = PrivatePlayerSchemeHandler()
        @Injected(.testable) static var preferences: [WKWebViewConfiguration.Preference] = [
            \WKWebViewConfiguration.allowsAirPlayForMediaPlayback: true,
            \WKWebViewConfiguration.preferences.javaScriptCanOpenWindowsAutomatically: true,
            \WKWebViewConfiguration.preferences.isFraudulentWebsiteWarningEnabled: false,
            "preferences.fullScreenEnabled": true,
            "preferences.allowsPictureInPictureMediaPlayback": true,
            "preferences.developerExtrasEnabled": true,
            "preferences.backspaceKeyNavigationEnabled": false
        ]

        @Injected(forTests: PassthroughSubject().eraseToAnyPublisher()) static var userContentBlockingAssets: AnyPublisher =
            ContentBlocking.shared.userContentUpdating.userContentBlockingAssets

        private static var privacyConfigurationManagerMock: PrivacyConfigurationManaging {
            ((NSClassFromString("MockPrivacyConfigurationManager") as? NSObject.Type)!.init() as? PrivacyConfigurationManaging)!
        }
        @Injected(forTests: privacyConfigurationManagerMock) static var privacyConfigurationManager: PrivacyConfigurationManaging =
            ContentBlocking.shared.privacyConfigurationManager
        @Injected(.testable) static var geolocationProviderFactory: (WKProcessPool) -> GeolocationProviderProtocol? = {
            GeolocationProvider(processPool: $0, geolocationService: GeolocationService.shared)
        }
    }

    func applyStandardConfiguration(with delegate: UserContentControllerDelegate) {
        self.apply(Dependencies.preferences)

        if urlSchemeHandler(forURLScheme: PrivatePlayer.privatePlayerScheme) == nil {
            setURLSchemeHandler(Dependencies.privatePlayerSchemeHandler, forURLScheme: PrivatePlayer.privatePlayerScheme)
        }

        let userContentController = UserContentController(assetsPublisher: Dependencies.userContentBlockingAssets,
                                                          privacyConfigurationManager: Dependencies.privacyConfigurationManager)
        userContentController.delegate = delegate
        self.userContentController = userContentController

        self.processPool.geolocationProvider = Dependencies.geolocationProviderFactory(self.processPool)
     }

}

extension WKWebViewConfiguration {
    public struct Preference {
        let kvcKeyPathOrString: KVCKeyPathOrString
        let value: Any

        static func apply(to configuration: WKWebViewConfiguration) -> (Preference) -> Void {
            { preference in
                guard let key = preference.kvcKeyPathOrString.keyPath else {
                    assertionFailure("\(preference.kvcKeyPathOrString)._kvcKeyPathString not available")
                    return
                }

                NSException.try {
                    configuration.setValue(preference.value, forKeyPath: key)
                }.map {
                    assertionFailure("\($0)")
                }
            }
        }
    }

    func apply(_ preferences: [Preference]) {
        preferences.forEach(Preference.apply(to: self))
    }
}

public protocol KVCKeyPathOrString {
    var keyPath: String? { get }
}
extension ReferenceWritableKeyPath: KVCKeyPathOrString where Root == WKWebViewConfiguration {
    public var keyPath: String? { _kvcKeyPathString }
}
extension String: KVCKeyPathOrString {
    public var keyPath: String? { self }
}
extension [WKWebViewConfiguration.Preference]: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (KVCKeyPathOrString, Any)...) {
        self = elements.compactMap(WKWebViewConfiguration.Preference.init)
    }
}
