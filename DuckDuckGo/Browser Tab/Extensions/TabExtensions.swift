//
//  TabExtensions.swift
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

import BrowserServicesKit
import Combine
import Foundation
import PrivacyDashboard

// Tab Extensions should conform to TabExtension protocol
protocol TabExtension {
    associatedtype PublicProtocol
    func getPublicProtocol() -> PublicProtocol
}

/** To access an extension from other places extend the Tab and use `resolve()` to get an extension:
```
 class MyTabExtension: TabExtension {
   fileprivate var featureModel: FeatureModel
 }

 extension Tab {
   var myFeature: FeatureModel? {
     extensions.resolve(MyTabExtension.self)?.featureModel
   }
 }
 ```
 **/

// Implement these methods for Extension State Restoration
protocol NSCodingExtension: TabExtension {
    func encode(using coder: NSCoder)
    func awakeAfter(using decoder: NSCoder)
}

protocol TabExtensionDependencies {
    var userScriptsPublisher: AnyPublisher<UserScripts?, Never> { get }
    var contentBlocking: ContentBlockingProtocol { get }
    var adClickAttributionDependencies: AdClickAttributionDependencies { get }
    var privacyInfoPublisher: AnyPublisher<PrivacyInfo?, Never> { get }

    var inheritedAttribution: AdClickAttributionLogic.State? { get }
    var userContentControllerProvider: UserContentControllerProvider { get }
}

struct AppTabExtensions: TabExtensionInstantiation {

    /// Instantiate `TabExtension`-s for App builds here
    /// Note: Extensions with state restoration support should conform to `NSCodingExtension`
    func make(with dependencies: TabExtensionDependencies) -> TabExtensions {
        let userScripts = dependencies.userScriptsPublisher

        AdClickAttributionTabExtension(inheritedAttribution: dependencies.inheritedAttribution,
                                       userContentControllerProvider: dependencies.userContentControllerProvider,
                                       contentBlockerRulesScriptPublisher: userScripts.map(\.?.contentBlockerRulesScript),
                                       privacyInfoPublisher: dependencies.privacyInfoPublisher,
                                       dependencies: dependencies.adClickAttributionDependencies)

        AutofillTabExtension(autofillUserScriptPublisher: userScripts.map(\.?.autofillScript))
        ContextMenuManager(contextMenuScriptPublisher: userScripts.map(\.?.contextMenuScript))
        HoveredLinkTabExtension(hoverUserScriptPublisher: userScripts.map(\.?.hoverUserScript))
        FindInPageTabExtension(findInPageScriptPublisher: userScripts.map(\.?.findInPageScript))
    }

}

#if DEBUG
struct TestTabExtensions: TabExtensionInstantiation {

    /// Add `TabExtension`-s that should be loaded when running Unit Tests here
    /// By default the Extensions won‘t be loaded
    func make(with dependencies: TabExtensionDependencies) -> TabExtensions {

    }

}
#endif
