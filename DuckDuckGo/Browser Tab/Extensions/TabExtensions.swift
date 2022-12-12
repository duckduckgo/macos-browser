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
import ContentBlocking
import Foundation
import PrivacyDashboard

/**
 Tab Extensions should conform to TabExtension protocol
 To access an extension from other places you need to define its Public Protocol and extend `TabExtensions` using `resolve(ExtensionClass.self)` to get the extension:
```
    class MyTabExtension {
      fileprivate var featureModel: FeatureModel
    }

    protocol MyExtensionPublicProtocol {
      var publicVar { get }
    }

    extension MyTabExtension: TabExtension, MyExtensionPublicProtocol {
      func getPublicProtocol() -> MyExtensionPublicProtocol { self }
    }

    extension TabExtensions {
      var myFeature: MyExtensionPublicProtocol? {
        extensions.resolve(MyTabExtension.self)
      }
    }
 ```
 **/
protocol TabExtension {
    associatedtype PublicProtocol
    func getPublicProtocol() -> PublicProtocol
}

// Implement these methods for Extension State Restoration
protocol NSCodingExtension: TabExtension {
    func encode(using coder: NSCoder)
    func awakeAfter(using decoder: NSCoder)
}

// Define dependencies used to instantiate TabExtensions here:
protocol TabExtensionDependencies {
    var userScriptsPublisher: AnyPublisher<UserScripts?, Never> { get }
    var contentBlocking: ContentBlockingProtocol { get }
    var adClickAttributionDependencies: AdClickAttributionDependencies { get }
    var privacyInfoPublisher: AnyPublisher<PrivacyInfo?, Never> { get }

    var inheritedAttribution: AdClickAttributionLogic.State? { get }
    var userContentControllerProvider: UserContentControllerProvider { get }
}

extension AppTabExtensions {

    /// Instantiate `TabExtension`-s for App builds here
    /// use add { return SomeTabExtensions() } to register Tab Extensions
    /// assign a result of add { .. } to a variable to use the registered Extensions for providing dependencies to other extensions
    /// ` add { MySimpleExtension() }
    /// ` let myPublishingExtension = add { MyPublishingExtension() }
    /// ` add { MyOtherExtension(with: myExtension.resultPublisher) }
    /// Note: Extensions with state restoration support should conform to `NSCodingExtension`
    mutating func make(with dependencies: TabExtensionDependencies) {
        let userScripts = dependencies.userScriptsPublisher

        let trackerInfoPublisher = dependencies.privacyInfoPublisher
            .compactMap { $0?.$trackerInfo }
            .switchToLatest()
            .scan( (old: Set<DetectedRequest>(), new: Set<DetectedRequest>()) ) {
                ($0.new, $1.trackers)
            }
            .map { (old, new) in
                new.subtracting(old).publisher
            }
            .switchToLatest()

        add {
            AdClickAttributionTabExtension(inheritedAttribution: dependencies.inheritedAttribution,
                                           userContentControllerProvider: dependencies.userContentControllerProvider,
                                           contentBlockerRulesScriptPublisher: userScripts.map(\.?.contentBlockerRulesScript),
                                           trackerInfoPublisher: trackerInfoPublisher,
                                           dependencies: dependencies.adClickAttributionDependencies)
        }
        add {
            AutofillTabExtension(autofillUserScriptPublisher: userScripts.map(\.?.autofillScript))
        }
        add {
            ContextMenuManager(contextMenuScriptPublisher: userScripts.map(\.?.contextMenuScript))
        }
        add {
            HoveredLinkTabExtension(hoverUserScriptPublisher: userScripts.map(\.?.hoverUserScript))
        }
        add {
            FindInPageTabExtension(findInPageScriptPublisher: userScripts.map(\.?.findInPageScript))
        }
    }

}

#if DEBUG
extension TestTabExtensions {

    /// Add `TabExtension`-s that should be loaded when running Unit Tests here
    /// By default the Extensions won‘t be loaded
    mutating func make(with dependencies: TabExtensionDependencies) {

    }

}
#endif
