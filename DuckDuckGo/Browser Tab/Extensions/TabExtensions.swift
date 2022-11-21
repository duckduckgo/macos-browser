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
    let printing: TabPrintExtension?
    let navigations: TabNavigationsProtocol
    let navigationDelegate: DistributedNavigationDelegate

    @Injected(forTests: defaultExtensionsForTests)
    static var buildForTab: (Tab) -> TabExtensions = { tab in
        return TabExtensions(adClickAttribution: AdClickAttributionTabExtension(tab: tab),
                             contextMenu: ContextMenuManager(tab: tab),
                             printing: TabPrintExtension(tab: tab),
                             navigations: TabNavigations(),
                             navigationDelegate: DistributedNavigationDelegate())
    }

    private static func defaultExtensionsForTests(_ tab: Tab) -> TabExtensions {
        return TabExtensions(adClickAttribution: nil,
                             contextMenu: nil,
                             printing: nil,
                             navigations: TabNavigations(),
                             navigationDelegate: DistributedNavigationDelegate())
    }

}
