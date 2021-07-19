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
    static let notNow = NSLocalizedString("notnow", value: "Not Now", comment: "Not Now button")
    static let open = NSLocalizedString("open", value: "Open", comment: "Open button")
    static let save = NSLocalizedString("save", value: "Save", comment: "Save button")
    static let edit = NSLocalizedString("edit", value: "Edit", comment: "Edit button")
    static let remove = NSLocalizedString("remove", value: "Remove", comment: "Remove button")

    static let duplicateTab = NSLocalizedString("duplicate.tab", value: "Duplicate Tab", comment: "Menu item. Duplicate as a verb")
    static let closeTab = NSLocalizedString("close.tab", value: "Close Tab", comment: "Menu item")
    static let closeOtherTabs = NSLocalizedString("close.other.tabs", value: "Close Other Tabs", comment: "Menu item")
    static let openInNewTab = NSLocalizedString("open.in.new.tab", value: "Open in New Tab", comment: "Menu item that opens the link in a new tab")
    static let openInNewWindow = NSLocalizedString("open.in.new.window", value: "Open in New Window", comment: "Menu item that opens the link in a new window")

    static let tabHomeTitle = NSLocalizedString("tab.home.title", value: "Home", comment: "Tab home title")
    static let tabPreferencesTitle = NSLocalizedString("tab.preferences.title", value: "Preferences", comment: "Tab preferences title")
    static let tabBookmarksTitle = NSLocalizedString("tab.bookmarks.title", value: "Bookmarks", comment: "Tab bookmarks title")
    static let tabErrorTitle = NSLocalizedString("tab.error.title", value: "Oops!", comment: "Tab error title")

    static let moveTabToNewWindow = NSLocalizedString("options.menu.move.tab.to.new.window",
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
    static let saveImageAs = NSLocalizedString("save.image.as", value: "Save Image As...", comment: "Context menu item")
    static let downloadLinkedFileAs = NSLocalizedString("save.image.as", value: "Download Linked File As...", comment: "Context menu item")
    static let searchWithDuckDuckGo = NSLocalizedString("search.with.DuckDuckGo", value: "Search with DuckDuckGo", comment: "Context menu item")

    static let findInPage = NSLocalizedString("find.in.page", value: "%1$d of %2$d", comment: "Find in page status (e.g. 1 of 99)")

    static let fireproofSite = NSLocalizedString("options.menu.fireproof-site", value: "Fireproof Site", comment: "Context menu item")
    static let removeFireproofing = NSLocalizedString("options.menu.remove-fireproofing", value: "Remove Fireproofing", comment: "Context menu item")
    static let fireproof = NSLocalizedString("fireproof", value: "Fireproof", comment: "Fireproof button")

    static func domainIsFireproof(domain: String) -> String {
        let localized = NSLocalizedString("fireproof", value: "%@ is Fireproof", comment: "Domain fireproof status")
        return String(format: localized, domain)
    }

    static func fireproofConfirmationTitle(domain: String) -> String {
        let localized = NSLocalizedString("fireproof.confirmation.title",
                                          value: "Would you like to Fireproof %@?",
                                          comment: "Fireproof confirmation title")
        return String(format: localized, domain)
    }

    static let fireproofConfirmationMessage = NSLocalizedString("fireproof.confirmation.message",
                                                                value: "Fireproofing this site will keep you signed in after using the Fire Button.",
                                                                comment: "Fireproof confirmation message")

    static let bookmarks = NSLocalizedString("bookmarks", value: "Bookmarks", comment: "Button for bookmarks")
    static let bookmarksOpenInNewTabs = NSLocalizedString("bookmarks.open.in.new.tabs", value: "Open in New Tabs", comment: "Open all bookmarks in folder in new tabs")
    static let addToFavorites = NSLocalizedString("add.to.favorites", value: "Add to Favorites", comment: "Button for adding bookmarks to favorites")
    static let addFavorite = NSLocalizedString("add.favorite", value: "Add Favorite", comment: "Button for adding a favorite bookmark")
    static let editFavorite = NSLocalizedString("edit.favorite", value: "Edit Favorite", comment: "Header of the view that edits a favorite bookmark")
    static let editFolder = NSLocalizedString("edit.folder", value: "Edit Folder", comment: "Header of the view that edits a bookmark folder")
    static let removeFromFavorites = NSLocalizedString("remove.from.favorites", value: "Remove from Favorites", comment: "Button for removing bookmarks from favorites")
    static let bookmarkThisPage = NSLocalizedString("bookmark.this.page", value: "Bookmark This Page...", comment: "Menu item for bookmarking current page")

    static let zoom = NSLocalizedString("zoom", value: "Zoom", comment: "Menu with Zooming commands")

    static let emailOptionsMenuItem = NSLocalizedString("email.optionsMenu", value: "Email Protection", comment: "Menu item email feature")
    static let emailOptionsMenuCreateAddressSubItem = NSLocalizedString("email.optionsMenu.createAddress", value: "Create a Duck Address", comment: "Create an email alias sub menu item")
    static let emailOptionsMenuTurnOffSubItem = NSLocalizedString("email.optionsMenu.turnOff", value: "Turn off Email Protection", comment: "Turn off email sub menu item")
    static let emailOptionsMenuTurnOnSubItem = NSLocalizedString("email.optionsMenu.turnOn", value: "Turn on Email Protection", comment: "Turn on email sub menu item")

    static let newFolder = NSLocalizedString("folder.optionsMenu.newFolder", value: "New Folder", comment: "Option for creating a new folder")
    static let renameFolder = NSLocalizedString("folder.optionsMenu.renameFolder", value: "Rename Folder", comment: "Option for renaming a folder")
    static let deleteFolder = NSLocalizedString("folder.optionsMenu.deleteFolder", value: "Delete Folder", comment: "Option for deleting a folder")

    static func openExternalURLTitle(forAppName appName: String) -> String {
        let localized = NSLocalizedString("open.external.url.title",
                                          value: "Open in %@?",
                                          comment: "Open URL in another app dialog title with app name")
        return String(format: localized, appName)
    }

    static func openExternalURLMessage(forAppName appName: String) -> String {
        let localized = NSLocalizedString("open.external.url.message",
                                          value: "Do you want to view this content in the %@ app?",
                                          comment: "Open URL in another app dialog message with app name")
        return String(format: localized, appName)
    }

    static let openExternalURLTitleUnknownApp = NSLocalizedString("open.external.url.title.unknown.app", value: "Open in Another App?", comment: "Open URL in another app dialog title for unknown app")
    static let openExternalURLMessageUnknownApp = NSLocalizedString("open.external.url.message.unknown.app", value: "Do you want to view this content in another app?", comment: "Open URL in another app dialog message for unknown app")
    static let failedToOpenExternally = NSLocalizedString("open.externally.failed", value: "The app required to open that link can’t be found", comment: "’Link’ is link on a website")

    static let preferences = NSLocalizedString("preferences", value: "Preferences", comment: "Menu item for opening preferences")

    static let defaultBrowser = NSLocalizedString("preferences.default-browser", value: "Default Browser", comment: "Show default browser preferences")
    static let appearance = NSLocalizedString("preferences.appearance", value: "Appearance", comment: "Show appearance preferences")
    static let privacyAndSecurity = NSLocalizedString("preferences.privacy-and-security", value: "Privacy & Security", comment: "Show privacy and security browser preferences")
    static let downloads = NSLocalizedString("preferences.downloads", value: "Downloads", comment: "Show downloads browser preferences")
    static let isDefaultBrowser = NSLocalizedString("preferences.default-browser.active", value: "DuckDuckGo is your default browser", comment: "Indicate that the browser is the default")
    static let isNotDefaultBrowser = NSLocalizedString("preferences.default-browser.inactive", value: "DuckDuckGo is not your default browser.", comment: "Indicate that the browser is not the default")

    static func versionLabel(version: String, build: String) -> String {
        let localized = NSLocalizedString("version",
                                          value: "Version %@ (%@)",
                                          comment: "Displays the version and build numbers")
        return String(format: localized, version, build)
    }

    static let importLoginsSelectCSVFile = NSLocalizedString("import.logins.select-csv-file", value: "Select CSV File", comment: "Button text for selecting a CSV file")
    static let importLoginsSelectAnotherFile = NSLocalizedString("import.logins.select-another-file", value: "Select Another File", comment: "Button text for selecting another file")

}
