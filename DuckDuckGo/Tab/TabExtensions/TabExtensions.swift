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
extension TabExtension {
    static var publicProtocolType: Any.Type {
        PublicProtocol.self
    }
}

// Implement these methods for Extension State Restoration
protocol NSCodingExtension: TabExtension {
    func encode(using coder: NSCoder)
    func awakeAfter(using decoder: NSCoder)
}

// Define dependencies used to instantiate TabExtensions here:
protocol TabExtensionDependencies {
    var privacyFeatures: PrivacyFeaturesProtocol { get }
    var workspace: Workspace { get }
    var historyCoordinating: HistoryCoordinating { get }
    var downloadManager: FileDownloadManagerProtocol { get }
    var cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter? { get }
    var duckPlayer: DuckPlayer { get }
}

// swiftlint:disable large_tuple
// swiftlint:disable function_body_length

typealias TabExtensionsBuilderArguments = (
    tabIdentifier: UInt64,
    isTabPinned: () -> Bool,
    isTabDisposable: Bool,
    contentPublisher: AnyPublisher<Tab.TabContent, Never>,
    titlePublisher: AnyPublisher<String?, Never>,
    userScriptsPublisher: AnyPublisher<UserScripts?, Never>,
    inheritedAttribution: AdClickAttributionLogic.State?,
    userContentControllerFuture: Future<UserContentController, Never>,
    permissionModel: PermissionModel,
    webViewFuture: Future<WKWebView, Never>
)

extension TabExtensionsBuilder {

    /// Instantiate `TabExtension`-s for App builds here
    /// use add { return SomeTabExtensions() } to register Tab Extensions
    /// assign a result of add { .. } to a variable to use the registered Extensions for providing dependencies to other extensions
    /// ` add { MySimpleExtension() }
    /// ` let myPublishingExtension = add { MyPublishingExtension() }
    /// ` add { MyOtherExtension(with: myExtension.resultPublisher) }
    /// Note: Extensions with state restoration support should conform to `NSCodingExtension`
    mutating func registerExtensions(with args: TabExtensionsBuilderArguments, dependencies: TabExtensionDependencies) {
        let userScripts = args.userScriptsPublisher

        let httpsUpgrade = add {
            HTTPSUpgradeTabExtension(httpsUpgrade: dependencies.privacyFeatures.httpsUpgrade)
        }

        let fbProtection = add {
            FBProtectionTabExtension(privacyConfigurationManager: dependencies.privacyFeatures.contentBlocking.privacyConfigurationManager,
                                     userContentControllerFuture: args.userContentControllerFuture,
                                     clickToLoadUserScriptPublisher: userScripts.map(\.?.clickToLoadScript))
        }

        let contentBlocking = add {
            ContentBlockingTabExtension(fbBlockingEnabledProvider: fbProtection.value,
                                        userContentControllerFuture: args.userContentControllerFuture,
                                        cbaTimeReporter: dependencies.cbaTimeReporter,
                                        privacyConfigurationManager: dependencies.privacyFeatures.contentBlocking.privacyConfigurationManager,
                                        contentBlockerRulesUserScriptPublisher: userScripts.map(\.?.contentBlockerRulesScript),
                                        surrogatesUserScriptPublisher: userScripts.map(\.?.surrogatesScript))
        }

        add {
            PrivacyDashboardTabExtension(contentBlocking: dependencies.privacyFeatures.contentBlocking,
                                         autoconsentUserScriptPublisher: userScripts.map(\.?.autoconsentUserScript),
                                         didUpgradeToHttpsPublisher: httpsUpgrade.didUpgradeToHttpsPublisher,
                                         trackersPublisher: contentBlocking.trackersPublisher)
        }

        add {
            AdClickAttributionTabExtension(inheritedAttribution: args.inheritedAttribution,
                                           userContentControllerFuture: args.userContentControllerFuture,
                                           contentBlockerRulesScriptPublisher: userScripts.map { $0?.contentBlockerRulesScript },
                                           trackerInfoPublisher: contentBlocking.trackersPublisher.map { $0.request },
                                           dependencies: dependencies.privacyFeatures.contentBlocking)
        }

        add {
            NavigationProtectionTabExtension(contentBlocking: dependencies.privacyFeatures.contentBlocking)
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

        add {
            DownloadsTabExtension(downloadManager: dependencies.downloadManager)
        }
        add {
            HistoryTabExtension(isDisposable: args.isTabDisposable,
                                historyCoordinating: dependencies.historyCoordinating,
                                trackersPublisher: contentBlocking.trackersPublisher,
                                urlPublisher: args.contentPublisher.map { content in content.isUrl ? content.url : nil },
                                titlePublisher: args.titlePublisher)
        }
        add {
            ExternalAppSchemeHandler(workspace: dependencies.workspace, permissionModel: args.permissionModel)
        }
        add {
            NavigationHotkeyHandler(isTabPinned: args.isTabPinned)
        }

        add {
            DuckPlayerTabExtension(duckPlayer: dependencies.duckPlayer,
                                   scriptsPublisher: userScripts.compactMap { $0 })
        }
    }

}

#if DEBUG
extension TestTabExtensionsBuilder {

    /// Used by default for Tab instantiation if not provided in Tab(... extensionsBuilder: TestTabExtensionsBuilder([HistoryTabExtension.self])
    static var shared: TestTabExtensionsBuilder = .default

    static let `default` = TestTabExtensionsBuilder(overrideExtensions: TestTabExtensionsBuilder.overrideExtensions, [
        // FindInPageTabExtension.self, HistoryTabExtension.self, ... - add TabExtensions here to be loaded by default for ALL Unit Tests
    ])

    // override Tab Extensions initialisation registered in TabExtensionsBuilder.registerExtensions for Unit Tests
    func overrideExtensions(with args: TabExtensionsBuilderArguments, dependencies: TabExtensionDependencies) {
        /** ```
         let fbProtection = get(FBProtectionTabExtension.self)

         let contentBlocking = override {
         ContentBlockingTabExtension(fbBlockingEnabledProvider: fbProtection.value)
         }
         override {
         HistoryTabExtension(trackersPublisher: contentBlocking.trackersPublisher)
         }
         ...
         */

    }

}
#endif
