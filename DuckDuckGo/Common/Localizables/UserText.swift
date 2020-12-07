//
//  UserText.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

struct UserText {

    static let ok = NSLocalizedString("ok", value: "OK", comment: "OK button")
    static let cancel = NSLocalizedString("cancel", value: "Cancel", comment: "Cancel button")

    static let duplicateTab = NSLocalizedString("duplicate.tab", value: "Duplicate Tab", comment: "Menu item. Duplicate as a verb")
    static let closeTab = NSLocalizedString("close.tab", value: "Close Tab", comment: "Menu item")
    static let closeOtherTabs = NSLocalizedString("close.other.tabs", value: "Close Other Tabs", comment: "Menu item")

    static let tabHomeTitle = NSLocalizedString("tab.home.title", value: "Home", comment: "Tab home title")
    static let tabErrorTitle = NSLocalizedString("tab.error.title", value: "Oops!", comment: "Tab error title")

    static let optionsMenuMoveTabToNewWindow = NSLocalizedString("options.menu.move.tab.to.new.window",
                                                                 value: "Move Tab to New Window",
                                                                 comment: "Context menu item")

    static let addressBarSearchSuffix = NSLocalizedString("address.bar.search.suffix",
                                                          value: "Search DuckDuckGo",
                                                          comment: "Suffix of searched terms in address bar. Example: best watching machine . Search DuckDuckGo")
    static let addressBarVisitSuffix = NSLocalizedString("address.bar.visit.suffix",
                                                          value: "Visit",
                                                          comment: "Address bar suffix of possibly visited website. Example: spreadprivacy.com . Visit spreadprivacy.com")

    static let burnAlertMessageText = NSLocalizedString("burn.alert.message.text",
                                                        value: "Are you sure you want to burn everything?",
                                                        comment: "")
    static let burtAlertInformativeText = NSLocalizedString("burn.alert.informative.text",
                                                            value: "This will close all tabs and clear website data.",
                                                            comment: "")
    static let burn = NSLocalizedString("burn", value: "Burn", comment: "Burn button")

    static let navigateBack = NSLocalizedString("navigate.back", value: "Back", comment: "Context menu item")
    static let navigateForward = NSLocalizedString("navigate.forward", value: "Forward", comment: "Context menu item")
    static let reloadPage = NSLocalizedString("reload.page", value: "Reload Page", comment: "Context menu item")

    static let openLinkInNewTab = NSLocalizedString("open.link.in.new.tab", value: "Open Link in New Tab", comment: "Context menu item")
    static let openImageInNewTab = NSLocalizedString("open.image.in.new.tab", value: "Open Image in New Tab", comment: "Context menu item")
    static let copyImageAddress = NSLocalizedString("copy.image.address", value: "Copy Image Address", comment: "Context menu item")

}
