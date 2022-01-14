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
    static let quit = NSLocalizedString("quit", value: "Quit", comment: "Quit button")
    static let dontQuit = NSLocalizedString("dont.quit", value: "Don’t Quit", comment: "Don’t Quit button")
    static let next = NSLocalizedString("next", value: "Next", comment: "Next button")

    static let duplicateTab = NSLocalizedString("duplicate.tab", value: "Duplicate Tab", comment: "Menu item. Duplicate as a verb")
    static let closeTab = NSLocalizedString("close.tab", value: "Close Tab", comment: "Menu item")
    static let closeOtherTabs = NSLocalizedString("close.other.tabs", value: "Close Other Tabs", comment: "Menu item")
    static let closeTabsToTheRight = NSLocalizedString("close.tabs.to.the.right", value: "Close Tabs to the Right", comment: "Menu item")
    static let openInNewTab = NSLocalizedString("open.in.new.tab", value: "Open in New Tab", comment: "Menu item that opens the link in a new tab")
    static let openInNewWindow = NSLocalizedString("open.in.new.window", value: "Open in New Window", comment: "Menu item that opens the link in a new window")

    static let tabHomeTitle = NSLocalizedString("tab.home.title", value: "Home", comment: "Tab home title")
    static let tabPreferencesTitle = NSLocalizedString("tab.preferences.title", value: "Preferences", comment: "Tab preferences title")
    static let tabBookmarksTitle = NSLocalizedString("tab.bookmarks.title", value: "Bookmarks", comment: "Tab bookmarks title")
    static let tabOnboardingTitle = NSLocalizedString("tab.onboarding.title", value: "Welcome", comment: "Tab onboarding title")
    static let tabErrorTitle = NSLocalizedString("tab.error.title", value: "Oops!", comment: "Tab error title")

    static let unknownErrorMessage = NSLocalizedString("error.unknown", value: "An unknown error has occurred", comment: "Error page subtitle")

    static let moveTabToNewWindow = NSLocalizedString("options.menu.move.tab.to.new.window",
                                                      value: "Move Tab to New Window",
                                                      comment: "Context menu item")

    static let searchDuckDuckGoSuffix = NSLocalizedString("address.bar.search.suffix",
                                                          value: "Search DuckDuckGo",
                                                          comment: "Suffix of searched terms in address bar. Example: best watching machine . Search DuckDuckGo")
    static let addressBarVisitSuffix = NSLocalizedString("address.bar.visit.suffix",
                                                         value: "Visit",
                                                         comment: "Address bar suffix of possibly visited website. Example: spreadprivacy.com . Visit spreadprivacy.com")

    static let burnAlertMessageText = NSLocalizedString("burn.alert.message.text",
                                                        value: "Are you sure you want to burn everything?",
                                                        comment: "")
    static let burnAlertInformativeText = NSLocalizedString("burn.alert.informative.text",
                                                            value: "This will close all tabs and clear website data.",
                                                            comment: "")
    static let burn = NSLocalizedString("burn", value: "Burn", comment: "Burn button")

    static let navigateBack = NSLocalizedString("navigate.back", value: "Back", comment: "Context menu item")
    static let closeAndReturnToParentFormat = NSLocalizedString("close.tab.on.back.format",
                                                                value: "Close and Return to “%@”",
                                                                comment: "Close Child Tab on Back Button press and return Back to the Parent Tab titled “%@”")
    static let closeAndReturnToParent = NSLocalizedString("close.tab.on.back",
                                                          value: "Close and Return to Previous Tab",
                                                          comment: "Close Child Tab on Back Button press and return Back to the Parent Tab without title")

    static let navigateForward = NSLocalizedString("navigate.forward", value: "Forward", comment: "Context menu item")
    static let reloadPage = NSLocalizedString("reload.page", value: "Reload Page", comment: "Context menu item")

    static let openLinkInNewTab = NSLocalizedString("open.link.in.new.tab", value: "Open Link in New Tab", comment: "Context menu item")
    static let openImageInNewTab = NSLocalizedString("open.image.in.new.tab", value: "Open Image in New Tab", comment: "Context menu item")
    static let copyImageAddress = NSLocalizedString("copy.image.address", value: "Copy Image Address", comment: "Context menu item")
    static let saveImageAs = NSLocalizedString("save.image.as", value: "Save Image As…", comment: "Context menu item")
    static let downloadLinkedFileAs = NSLocalizedString("save.image.as", value: "Download Linked File As…", comment: "Context menu item")
    static let searchWithDuckDuckGo = NSLocalizedString("search.with.DuckDuckGo", value: "Search with DuckDuckGo", comment: "Context menu item")

    static let plusButtonNewTabMenuItem = NSLocalizedString("menu.item.new.tab", value: "New Tab", comment: "Context menu item")

    static let findInPage = NSLocalizedString("find.in.page", value: "%1$d of %2$d", comment: "Find in page status (e.g. 1 of 99)")

    static let moreMenuItem = NSLocalizedString("sharing.more", value: "More…", comment: "Sharing Menu -> More…")
    static let findInPageMenuItem = NSLocalizedString("find.in.page.menu.item", value: "Find in Page…", comment: "Menu item title")
    static let shareMenuItem = NSLocalizedString("share.menu.item", value: "Share", comment: "Menu item title")
    static let printMenuItem = NSLocalizedString("print.menu.item", value: "Print…", comment: "Menu item title")
    static let newWindowMenuItem = NSLocalizedString("new.window.menu.item", value: "New Window", comment: "Menu item title")

    static let fireDialogFireproofSites = NSLocalizedString("fire.dialog.fireproof.sites", value: "Fireproof Sites", comment: "Category of domains in fire button dialog")
    static let fireDialogClearSites = NSLocalizedString("fire.dialog.clear.sites", value: "Clear These Sites", comment: "Category of domains in fire button dialog")
    static let allData = NSLocalizedString("fire.all-data", value: "All Data", comment: "Configuration option for fire button")
    static let currentTab = NSLocalizedString("fire.currentTab", value: "Current Tab", comment: "Configuration option for fire button")
    static let currentWindow = NSLocalizedString("fire.currentWindow", value: "Current Window", comment: "Configuration option for fire button")
    static let allDataDescription = NSLocalizedString("fire.all-data.description", value: "Clear all tabs and related site data", comment: "Description of the 'All Data' configuration option for the fire button")
    static let currentTabDescription = NSLocalizedString("fire.current-tab.description", value: "Close current tab and clear related site data", comment: "Description of the 'Current Tab' configuration option for the fire button")
    static let currentWindowDescription = NSLocalizedString("fire.current-window.description", value: "Clear current window and related site data", comment: "Description of the 'Current Window' configuration option for the fire button")
    static let selectedDomainsDescription = NSLocalizedString("fire.selected-domains.description", value: "Clear selected domains and related site data", comment: "Description of the 'Current Window' configuration option for the fire button")
    static let fireDialogNothingToBurn = NSLocalizedString("fire.dialog.nothing-to-burn", value: "Nothing to burn", comment: "Information label to inform there is no domain for burning")
    static let fireDialogDetails = NSLocalizedString("fire.dialog.details", value: "Details", comment: "Button to show more details")
    static let fireproofSite = NSLocalizedString("options.menu.fireproof-site", value: "Fireproof This Site", comment: "Context menu item")
    static let removeFireproofing = NSLocalizedString("options.menu.remove-fireproofing", value: "Remove Fireproofing", comment: "Context menu item")
    static let fireproof = NSLocalizedString("fireproof", value: "Fireproof", comment: "Fireproof button")

    static func domainIsFireproof(domain: String) -> String {
        let localized = NSLocalizedString("fireproof", value: "%@ is now Fireproof", comment: "Domain fireproof status")
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
    
    static let gpcLearnMore = NSLocalizedString("gpc.learnmore.link", value: "Learn More", comment: "Learn More link")

    static let passwordManagement = NSLocalizedString("passsword.management", value: "Logins+", comment: "Used as title for password management user interface")

    static let bookmarks = NSLocalizedString("bookmarks", value: "Bookmarks", comment: "Button for bookmarks")
    static let bookmarksOpenInNewTabs = NSLocalizedString("bookmarks.open.in.new.tabs", value: "Open in New Tabs", comment: "Open all bookmarks in folder in new tabs")
    static let addToFavorites = NSLocalizedString("add.to.favorites", value: "Add to Favorites", comment: "Button for adding bookmarks to favorites")
    static let addFavorite = NSLocalizedString("add.favorite", value: "Add Favorite", comment: "Button for adding a favorite bookmark")
    static let editFavorite = NSLocalizedString("edit.favorite", value: "Edit Favorite", comment: "Header of the view that edits a favorite bookmark")
    static let editFolder = NSLocalizedString("edit.folder", value: "Edit Folder", comment: "Header of the view that edits a bookmark folder")
    static let removeFromFavorites = NSLocalizedString("remove.from.favorites", value: "Remove from Favorites", comment: "Button for removing bookmarks from favorites")
    static let bookmarkThisPage = NSLocalizedString("bookmark.this.page", value: "Bookmark This Page…", comment: "Menu item for bookmarking current page")

    static let zoom = NSLocalizedString("zoom", value: "Zoom", comment: "Menu with Zooming commands")

    static let emailOptionsMenuItem = NSLocalizedString("email.optionsMenu", value: "Email Protection", comment: "Menu item email feature")
    static let emailOptionsMenuCreateAddressSubItem = NSLocalizedString("email.optionsMenu.createAddress", value: "Create a Duck Address", comment: "Create an email alias sub menu item")
    static let emailOptionsMenuTurnOffSubItem = NSLocalizedString("email.optionsMenu.turnOff", value: "Disable Email Protection", comment: "Disable email sub menu item")
    static let emailOptionsMenuTurnOnSubItem = NSLocalizedString("email.optionsMenu.turnOn", value: "Enable Email Protection", comment: "Enable email sub menu item")
    static let privateEmailCopiedToClipboard = NSLocalizedString("email.copied", value: "New address copied to your clipboard", comment: "Private email address was copied to clipboard message")

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

    static let devicePermissionAuthorizationFormat = NSLocalizedString("permission.authorization.format",
                                                                       value: "Allow “%@“ to use your %@?",
                                                                       comment: "Popover asking for domain %@ to use camera/mic/location (%@)")
    static let popupWindowsPermissionAuthorizationFormat = NSLocalizedString("permission.authorization.popups",
                                                                             value: "Allow “%@“ to open PopUp Window?",
                                                                             comment: "Popover asking for domain %@ to open Popup Window")
    static let permissionMicrophone = NSLocalizedString("permission.microphone", value: "Microphone", comment: "Microphone input media device name")
    static let permissionCamera = NSLocalizedString("permission.camera", value: "Camera", comment: "Camera input media device name")
    static let permissionCameraAndMicrophone = NSLocalizedString("permission.cameraAndmicrophone", value: "use your Camera and Microphone", comment: "camera and microphone input media devices name")
    static let permissionGeolocation = NSLocalizedString("permission.geolocation", value: "Geolocation", comment: "User's Geolocation permission access name")
    static let permissionPopups = NSLocalizedString("permission.popups", value: "Pop-ups", comment: "Open Pop Up Windows permission access name")

    static let permissionMuteFormat = NSLocalizedString("permission.mute", value: "Pause %@", comment: "Temporarily pause input media device %@ access")
    static let permissionUnmuteFormat = NSLocalizedString("permission.unmute", value: "Resume %@", comment: "Resume input media device %@ access")
    static let permissionRevokeFormat = NSLocalizedString("permission.revoke", value: "Stop %@ Access", comment: "Revoke input media device %@ access")
    static let permissionReloadToEnable = NSLocalizedString("permission.reloadPage", value: "Reload to Ask Again", comment: "Reload webpage to ask for input media device access permission again")

    static let permissionAlwaysAllowFormat = NSLocalizedString("permission.always.allow", value: "Always Allow on “%@“", comment: "Make input media device access permanently allowed for current domain")
    static let permissionAlwaysAskFormat = NSLocalizedString("permission.always.ask", value: "Always Ask on “%@“", comment: "Make input media device access always asked from user for current domain")
    static let permissionAlwaysDenyFormat = NSLocalizedString("permission.always.deny.dashboard", value: "Always Deny on “%@“", comment: "Make input media device access permanently disabled for current domain (Option in Privacy Dashboard)")

    static let permissionAlwaysAllowDeviceFormat = NSLocalizedString("permission.always.allow", value: "Always Allow %@ on “%@“", comment: "Make input media device access permanently allowed for current domain")
    static let permissionAlwaysAskDeviceFormat = NSLocalizedString("permission.always.ask", value: "Always Ask for %@ on “%@“", comment: "Make input media device access always asked from user for current domain")
    static let permissionAlwaysDenyDeviceFormat = NSLocalizedString("permission.always.deny.device", value: "Never Ask for %@ again for “%@“", comment: "Make input media device access permanently allowed for current domain")

    static let permissionAppPermissionDisabledFormat = NSLocalizedString("permission.disabled.app", value: "%@ %@ access is disabled", comment: "The app (%@) has no access permission to %@ media device")
    static let permissionGeolocationServicesDisabled = NSLocalizedString("permission.disabled.system", value: "System Geolocation Services are disabled", comment: "Geolocation Services are disabled in System Preferences")
    static let permissionOpenSystemPreferences = NSLocalizedString("permission.open.preferences", value: "Open System Preferences", comment: "Open System Preferences (to re-enable permission for the App)")

    static let permissionPopupTitleFormat = NSLocalizedString("permission.popup.title.format", value: "Blocked Pop-ups", comment: "Website requested permission to open a Popup with %@ URL")
    static let permissionPopupOpenFormat = NSLocalizedString("permission.popup.open.format", value: "%@", comment: "Open %@ URL Pop-up")

    static let privacyDashboardPermissionAsk = NSLocalizedString("dashboard.permission.ask", value: "Ask", comment: "Privacy Dashboard: Website should always Ask for permission for input media device access")
    static let privacyDashboardPermissionAlwaysAllow = NSLocalizedString("dashboard.permission.allow", value: "Allow Always", comment: "Privacy Dashboard: Website can always access input media device")
    static let privacyDashboardPermissionAlwaysDeny = NSLocalizedString("dashboard.permission.deny", value: "Deny Always", comment: "Privacy Dashboard: Website can never access input media device")

    static let privacyDashboardPopupsAlwaysAsk = NSLocalizedString("dashboard.popups.ask", value: "Notify", comment: "Make PopUp Windows always asked from user for current domain")

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

    // MARK: - Login Import & Export

    static func closeBrowserWarningFor(browser: String) -> String {
        let localized = NSLocalizedString("import.close.browser.warning", value: "You must quit %@ before importing data.", comment: "Quit browser warning when importing data")
        return String(format: localized, browser)
    }

    static let importLoginsCSV = NSLocalizedString("import.logins.csv.title", value: "CSV Logins File", comment: "Title text for the CSV importer")

    static let csvImportDescription = NSLocalizedString("import.logins.csv.description", value: "The CSV importer will try to match column headers to their position.\nIf there is no header, it supports two formats:\n\n1. URL, Username, Password\n2. Title, URL, Username, Password", comment: "Description text for the CSV importer")
    static let importLoginsSelectCSVFile = NSLocalizedString("import.logins.select-csv-file", value: "Select CSV File…", comment: "Button text for selecting a CSV file")
    static let importLoginsSelectAnotherFile = NSLocalizedString("import.logins.select-another-file", value: "Select Another CSV File…", comment: "Button text for selecting another file")
    static let importLoginsFailedToReadCSVFile = NSLocalizedString("import.logins.failed-to-read-file", value: "Failed to get CSV file URL", comment: "Error text when importing a CSV file")

    static func importingFile(validLogins: Int) -> String {
        let localized = NSLocalizedString("import.logins.csv.valid-logins",
                                          value: "Contains %@ valid logins",
                                          comment: "Displays the number of the logins being imported")
        return String(format: localized, String(validLogins))
    }

    static let initiateImport = NSLocalizedString("import.data.initiate", value: "Import", comment: "Button text for importing data")
    static let doneImporting = NSLocalizedString("import.data.done", value: "Done", comment: "Button text for finishing the data import")

    static let chromiumPasswordImportDisclaimer = NSLocalizedString("import.chromium.disclaimer", value: "Your Keychain password is temporarily needed to import passwords.", comment: "Warning text for the Chromium password import option")
    static let firefoxPasswordImportDisclaimer = NSLocalizedString("import.firefox.disclaimer", value: "Your Primary Password is temporarily needed to import passwords.", comment: "Warning text for the Chromium password import option")

    static let dataImportFailedTitle = NSLocalizedString("import.data.import-failed.title", value: "Import Failed", comment: "Alert title when the data import fails")

    static func dataImportFailedBody(_ source: DataImport.Source, errorMessage: String) -> String {
        let localized = NSLocalizedString("import.data.import-failed.body",
                                          value: "Failed to import data from %@.\n\nError message: %@",
                                          comment: "Alert body text when the data import fails")
        return String(format: localized, source.importSourceName, errorMessage)
    }

    static let dataImportAlertImport = NSLocalizedString("import.data.alert.import", value: "Import", comment: "Import button for data import alerts")
    static let dataImportAlertAccept = NSLocalizedString("import.data.alert.accept", value: "Okay", comment: "Accept button for data import alerts")
    static let dataImportAlertCancel = NSLocalizedString("import.data.alert.cancel", value: "Cancel", comment: "Cancel button for data import alerts")

    static let dataImportRequiresPasswordTitle = NSLocalizedString("import.data.requires-password.title", value: "Primary Password Required", comment: "Alert title text when the data import needs a password")

    static func dataImportRequiresPasswordBody(_ source: DataImport.Source) -> String {
        let localized = NSLocalizedString("import.data.requires-password.body",
                                          value: "A primary password is required to import %@ logins.",
                                          comment: "Alert body text when the data import needs a password")
        return String(format: localized, source.importSourceName)
    }

    static func dataImportBrowserMustBeClosed(_ source: DataImport.Source) -> String {
        let localized = NSLocalizedString("import.data.close-browser",
                                          value: "Please ensure that %@ is not running before importing data",
                                          comment: "Alert body text when the data import fails due to the browser being open")
        return String(format: localized, source.importSourceName)
    }

    static func dataImportQuitBrowserTitle(_ source: DataImport.Source) -> String {
        let localized = NSLocalizedString("import.data.quit-browser.title",
                                          value: "Would you like to quit %@ now?",
                                          comment: "Alert title text when prompting to close the browser")
        return String(format: localized, source.importSourceName)
    }

    static func dataImportQuitBrowserBody(_ source: DataImport.Source) -> String {
        let localized = NSLocalizedString("import.data.quit-browser.body",
                                          value: "You must quit %@ before importing data.",
                                          comment: "Alert body text when prompting to close the browser")
        return String(format: localized, source.importSourceName)
    }

    static func dataImportQuitBrowserButton(_ source: DataImport.Source) -> String {
        let localized = NSLocalizedString("import.data.quit-browser.accept-button",
                                          value: "Quit %@",
                                          comment: "Accept button text when prompting to close the browser")
        return String(format: localized, source.importSourceName)
    }

    static func loginImportSuccessfulCSVImports(totalSuccessfulImports: Int) -> String {
        let localized = NSLocalizedString("import.logins.csv.successful-imports",
                                          value: "New Logins: %@",
                                          comment: "Status text indicating the number of successful CSV login imports")
        return String(format: localized, String(totalSuccessfulImports))
    }

    static func loginImportSuccessfulBrowserImports(totalSuccessfulImports: Int) -> String {
        let localized = NSLocalizedString("import.logins.browser.successful-imports",
                                          value: "Passwords: %@",
                                          comment: "Status text indicating the number of successful browser login imports")
        return String(format: localized, String(totalSuccessfulImports))
    }

    static func successfulBookmarkImports(_ totalSuccessfulImports: Int) -> String {
        let localized = NSLocalizedString("import.bookmarks.browser.successful-imports",
                                          value: "Bookmarks: %@",
                                          comment: "Status text indicating the number of successful browser bookmark imports")
        return String(format: localized, String(totalSuccessfulImports))
    }

    static func duplicateBookmarkImports(_ totalFailedImports: Int) -> String {
        let localized = NSLocalizedString("import.bookmarks.browser.duplicate-imports",
                                          value: "Duplicate Bookmarks Skipped: %@",
                                          comment: "Status text indicating the number of duplicate browser bookmark imports")
        return String(format: localized, String(totalFailedImports))
    }

    static func failedBookmarkImports(_ totalFailedImports: Int) -> String {
        let localized = NSLocalizedString("import.bookmarks.browser.failed-imports",
                                          value: "Failed Imports: %@",
                                          comment: "Status text indicating the number of failed browser bookmark imports")
        return String(format: localized, String(totalFailedImports))
    }

    static let bookmarkImportSafariPermissionDescription = NSLocalizedString("import.bookmarks.safari.permission-description", value: "DuckDuckGo needs your permission to read the Safari bookmarks file. Select the Bookmarks.plist file to import bookmarks.", comment: "Description text for the Safari bookmark import permission screen")
    static let bookmarkImportSafariRequestPermissionButtonTitle = NSLocalizedString("import.bookmarks.safari.permission-button.title", value: "Select Bookmarks File…", comment: "Text for the Safari bookmark import permission button")

    static let bookmarkImportBookmarksBar = NSLocalizedString("import.bookmarks.folder.bookmarks-bar", value: "Bookmarks Bar", comment: "Title text for Bookmarks Bar import folder")
    static let bookmarkImportOtherBookmarks = NSLocalizedString("import.bookmarks.folder.other-bookmarks", value: "Other Bookmarks", comment: "Title text for Other Bookmarks import folder")

    static let openDeveloperTools = NSLocalizedString("main.menu.show.inspector", value: "Open Developer Tools", comment: "Show Web Inspector/Open Developer Tools")
    static let closeDeveloperTools = NSLocalizedString("main.menu.close.inspector", value: "Close Developer Tools", comment: "Hide Web Inspector/Close Developer Tools")

    static let authAlertTitle = NSLocalizedString("auth.alert.title", value: "Authentication Required", comment: "Authentication Alert Title")
    static let authAlertEncryptedConnectionMessageFormat = NSLocalizedString("auth.alert.message.encrypted", value: "Sign in to %@. Your login information will be sent securely.", comment: "Authentication Alert - populated with a domain name")
    static let authAlertPlainConnectionMessageFormat = NSLocalizedString("auth.alert.message.plain", value: "Log in to %@. Your password will be sent insecurely because the connection is unencrypted.", comment: "Authentication Alert - populated with a domain name")
    static let authAlertUsernamePlaceholder = NSLocalizedString("auth.alert.username.placeholder", value: "Username", comment: "Authentication User name field placeholder")
    static let authAlertPasswordPlaceholder = NSLocalizedString("auth.alert.password.placeholder", value: "Password", comment: "Authentication Password field placeholder")
    static let authAlertLogInButtonTitle = NSLocalizedString("auth.alert.login.button", value: "Sign In", comment: "Authentication Alert Sign In Button")

    static let openDownloads = NSLocalizedString("main.menu.show.downloads", value: "Show Downloads", comment: "Show Downloads Popover")
    static let closeDownloads = NSLocalizedString("main.menu.close.downloads", value: "Hide Downloads", comment: "Hide Downloads Popover")

    static let downloadedFileRemoved = NSLocalizedString("downloads.error.removed", value: "Removed", comment: "Short error description when downloaded file removed from Downloads folder")
    static let downloadStarting = NSLocalizedString("download.starting", value: "Starting download…", comment: "Download being initiated information text")
    static let downloadFinishing = NSLocalizedString("download.finishing", value: "Finishing download…", comment: "Download being finished information text")
    static let downloadCanceled = NSLocalizedString("downloads.error.canceled", value: "Canceled", comment: "Short error description when downloaded file download was canceled")
    static let downloadFailedToMoveFileToDownloads = NSLocalizedString("downloads.error.move.failed", value: "Could not move file to Downloads", comment: "Short error description when could not move downloaded file to the Downloads folder")
    static let downloadFailed = NSLocalizedString("downloads.error.other", value: "Error", comment: "Short error description when Download failed")

    static let cancelDownloadToolTip = NSLocalizedString("downloads.tooltip.cancel", value: "Cancel Download", comment: "Mouse-over tooltip for Cancel Download button")
    static let restartDownloadToolTip = NSLocalizedString("downloads.tooltip.restart", value: "Restart Download", comment: "Mouse-over tooltip for Restart Download button")
    static let redownloadToolTip = NSLocalizedString("downloads.tooltip.redownload", value: "Download Again", comment: "Mouse-over tooltip for Download [deleted file] Again button")
    static let revealToolTip = NSLocalizedString("downloads.tooltip.reveal", value: "Show in Finder", comment: "Mouse-over tooltip for Show in Finder button")

    static let downloadsActiveAlertTitle = NSLocalizedString("downloads.active.alert.title", value: "A download is in progress.", comment: "Alert title when trying to quit application while files are being downloaded")
    static let downloadsActiveAlertMessageFormat = NSLocalizedString("downloads.active.alert.message.format", value: "Are you sure you want to quit? DuckDuckGo Privacy Browser is currently downloading “%@”%@. If you quit now DuckDuckGo Privacy Browser won’t finish downloading this file.", comment: "Alert text format when trying to quit application while file “filename”[, and others] are being downloaded")
    static let downloadsActiveAlertMessageAndOthers = NSLocalizedString("downloads.active.alert.message.and.others", value: ", and other files", comment: "Alert text format element for “, and other files”")

    static let exportLoginsFailedMessage = NSLocalizedString("export.logins.failed.message", value: "Failed to Export Logins", comment: "Alert title when exporting login data fails")
    static let exportLoginsFailedInformative = NSLocalizedString("export.logins.failed.informative", value: "Please check that no file exists at the location you selected.", comment: "Alert message when exporting login data fails")
    static let exportBookmarksFailedMessage = NSLocalizedString("export.bookmarks.failed.message", value: "Failed to Export Bookmarks", comment: "Alert title when exporting login data fails")
    static let exportBookmarksFailedInformative = NSLocalizedString("export.bookmarks.failed.informative", value: "Please check that no file exists at the location you selected.", comment: "Alert message when exporting bookmarks fails")

    static let exportLoginsFileNameSuffix = NSLocalizedString("export.logins.file.name.suffix", value: "Logins", comment: "The last part of the suggested file name for exporting logins")
    static let exportBookmarksFileNameSuffix = NSLocalizedString("export.bookmarks.file.name.suffix", value: "Bookmarks", comment: "The last part of the suggested file for exporting bookmarks")

    static let onboardingWelcomeTitle = NSLocalizedString("onboarding.welcome.title", value: "Welcome to DuckDuckGo!", comment: "General welcome to the app title")
    static let onboardingWelcomeText = NSLocalizedString("onboarding.welcome.text", value: "Tired of being tracked online? You've come to the right place 👍\n\nI'll help you stay private️ as you search and browse the web. Trackers be gone!", comment: "Detailed welcome to the app text")
    static let onboardingImportDataText = NSLocalizedString("onboarding.importdata.text", value: "First, let me help you import your bookmarks 📖 and passwords 🔑 from those less private browsers.", comment: "Call to action to import data from other browsers")
    static let onboardingSetDefaultText = NSLocalizedString("onboarding.setdefault.text", value: "Next, try setting DuckDuckGo as your default️ browser, so you can open links with peace of mind, every time.", comment: "Call to action to set the browser as default")
    static let onboardingStartBrowsingText = NSLocalizedString("onboarding.startbrowsing.text", value: "You’re all set!\n\nWant to see how I protect you? Try visiting one of your favorite sites 👆\n\nKeep watching the address bar as you go. I’ll be blocking trackers and upgrading the security of your connection when possible\u{00A0}🔒", comment: "Call to action to start using the app as a browser")

    static let onboardingStartButton = NSLocalizedString("onboarding.welcome.button", value: "Get Started", comment: "Start the onboarding flow")
    static let onboardingImportDataButton = NSLocalizedString("onboarding.importdata.button", value: "Import", comment: "Launch the import data UI")
    static let onboardingSetDefaultButton = NSLocalizedString("onboarding.setdefault.button", value: "Let's Do It!", comment: "Launch the set default UI")
    static let onboardingNotNowButton = NSLocalizedString("onboarding.notnow.button", value: "Maybe Later", comment: "Skip a step of the onboarding flow")

    static let waitlistGetStarted = NSLocalizedString("waitlist.get-started", value: "Get Started", comment: "Button title used in the waitlist lock screen success state")

    static let importFromChromiumMoreInfo = NSLocalizedString("import.from.chromium.info", value: "You'll be asked to enter your Keychain password.\n\nDuckDuckGo won’t see your Keychain password, but macOS needs it to access and import passwords into DuckDuckGo.\n\nImported passwords are encrypted and only stored on this computer.", comment: "More info when importing from Chromium")

}
