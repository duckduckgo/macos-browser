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
import Foundation

protocol TabExtension {
    init()
    func attach(to tab: Tab)

    func encode(using coder: NSCoder)
    func awakeAfter(using decoder: NSCoder)
}
extension TabExtension {
    func encode(using coder: NSCoder) {}
    func awakeAfter(using coder: NSCoder) {}
}

struct TabExtensions {

    let instrumentation: TabInstrumentation
    let contentBlocking: ContentBlockingTabExtension?
    let adClickAttribution: AdClickAttributionTabExtension?
    let clickToLoad: ClickToLoad?
    let contextMenu: ContextMenuManager?
    let hoveredLinks: HoveredLinkTabExtension?
    let history: TabHistoryExtension?
    let printing: TabPrintExtension?
    let findInPage: FindInPageTabExtension?
    let autofill: AutofillTabExtension?
    let navigationDelegate: DistributedNavigationDelegate
    let linkProtection: LinkProtectionExtension?
    let referrerTrimming: ReferrerTrimmingTabExtension?
    let httpsUpgrade: HTTPSUpgradeTabExtension?
    let downloads: TabDownloadsExtension?
    let duckPlayer: DuckPlayerTabExtension?

    @Injected(forTests: extensionsForTests)
    static var createExtensions: () -> TabExtensions = {
        return TabExtensions(instrumentation: TabInstrumentation(),
                             contentBlocking: ContentBlockingTabExtension(),
                             adClickAttribution: AdClickAttributionTabExtension(),
                             clickToLoad: ClickToLoad(),
                             contextMenu: ContextMenuManager(),
                             hoveredLinks: HoveredLinkTabExtension(),
                             history: TabHistoryExtension(),
                             printing: TabPrintExtension(),
                             findInPage: FindInPageTabExtension(),
                             autofill: AutofillTabExtension(),
                             navigationDelegate: DistributedNavigationDelegate(),
                             linkProtection: LinkProtectionExtension(),
                             referrerTrimming: ReferrerTrimmingTabExtension(),
                             httpsUpgrade: HTTPSUpgradeTabExtension(),
                             downloads: TabDownloadsExtension(),
                             duckPlayer: DuckPlayerTabExtension())
    }

    private static func extensionsForTests() -> TabExtensions {
        return TabExtensions(instrumentation: TabInstrumentation(),
                             contentBlocking: nil,
                             adClickAttribution: nil,
                             clickToLoad: nil,
                             contextMenu: nil,
                             hoveredLinks: nil,
                             history: nil,
                             printing: nil,
                             findInPage: nil,
                             autofill: nil,
                             navigationDelegate: DistributedNavigationDelegate(),
                             linkProtection: nil,
                             referrerTrimming: nil,
                             httpsUpgrade: nil,
                             downloads: nil,
                             duckPlayer: nil)
    }

    func attach(to tab: Tab) {
        self.forEach { $0.attach(to: tab) }
    }

}

extension TabExtensions: Sequence {
    typealias Iterator = IndexingIterator<[TabExtension]>

    func makeIterator() -> Iterator {
        Mirror(reflecting: self).children.compactMap { child -> TabExtension? in
            guard let tabExtension = child.value as? TabExtension else {
                assertionFailure("\(child.label!) should conform to TabExtension")
                return nil
            }
            return tabExtension
        }.makeIterator()
    }

}
