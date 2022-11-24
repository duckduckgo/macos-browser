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

import Foundation

struct TabExtensions {

    let adClickAttribution: AdClickAttributionTabExtension?
    let contextMenu: ContextMenuManager?
    let hoveredLinks: HoveredLinkTabExtension?
    let printing: TabPrintExtension?
    let findInPage: FindInPageTabExtension?
    let autofill: AutofillTabExtension?

    @Injected(forTests: defaultExtensionsForTests)
    static var buildForTab: (Tab) -> TabExtensions = { tab in
        TabExtensions(adClickAttribution: AdClickAttributionTabExtension(tab: tab),
                      contextMenu: ContextMenuManager(tab: tab),
                      hoveredLinks: HoveredLinkTabExtension(tab: tab),
                      printing: TabPrintExtension(tab: tab),
                      findInPage: FindInPageTabExtension(tab: tab),
                      autofill: AutofillTabExtension(tab: tab))
    }

    private static func defaultExtensionsForTests(_ tab: Tab) -> TabExtensions {
        TabExtensions(adClickAttribution: nil,
                      contextMenu: nil,
                      hoveredLinks: nil,
                      printing: nil,
                      findInPage: nil,
                      autofill: nil)
    }

}
