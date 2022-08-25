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
    static let deleteBookmark = NSLocalizedString("delete-bookmark", value: "Delete Bookmark", comment: "Delete Bookmark button")
    static let removeFavorite = NSLocalizedString("remove-favorite", value: "Remove Favorite", comment: "Remove Favorite button")
    static let quit = NSLocalizedString("quit", value: "Quit", comment: "Quit button")
    static let dontQuit = NSLocalizedString("dont.quit", value: "Don’t Quit", comment: "Don’t Quit button")
    static let next = NSLocalizedString("next", value: "Next", comment: "Next button")
    static let pasteAndGo = NSLocalizedString("paste.and.go", value: "Paste & Go", comment: "Paste & Go button")
    static let pasteAndSearch = NSLocalizedString("paste.and.search", value: "Paste & Search", comment: "Paste & Search button")
    static let clear = NSLocalizedString("clear", value: "Clear", comment: "Clear button")

    static let duplicateTab = NSLocalizedString("duplicate.tab", value: "Duplicate Tab", comment: "Menu item. Duplicate as a verb")
    static let pinTab = NSLocalizedString("pin.tab", value: "Pin Tab", comment: "Menu item. Pin as a verb")
    static let unpinTab = NSLocalizedString("unpin.tab", value: "Unpin Tab", comment: "Menu item. Unpin as a verb")
    static let closeTab = NSLocalizedString("close.tab", value: "Close Tab", comment: "Menu item")
    static let closeOtherTabs = NSLocalizedString("close.other.tabs", value: "Close Other Tabs", comment: "Menu item")
    static let closeTabsToTheRight = NSLocalizedString("close.tabs.to.the.right", value: "Close Tabs to the Right", comment: "Menu item")
    static let openInNewTab = NSLocalizedString("open.in.new.tab", value: "Open in New Tab", comment: "Menu item that opens the link in a new tab")
    static let openInNewWindow = NSLocalizedString("open.in.new.window", value: "Open in New Window", comment: "Menu item that opens the link in a new window")

    static let tabHomeTitle = NSLocalizedString("tab.home.title", value: "Home", comment: "Tab home title")
    static let tabPreferencesTitle = NSLocalizedString("tab.preferences.title", value: "Settings", comment: "Tab preferences title")
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
    static let addLinkToBookmarks = NSLocalizedString("add.link.to.bookmarks", value: "Add Link to Bookmarks", comment: "Context menu item")
    static let bookmarkPage = NSLocalizedString("bookmark.page", value: "Bookmark Page", comment: "Context menu item")
    static let searchWithDuckDuckGo = NSLocalizedString("search.with.DuckDuckGo", value: "Search with DuckDuckGo", comment: "Context menu item")

    static let plusButtonNewTabMenuItem = NSLocalizedString("menu.item.new.tab", value: "New Tab", comment: "Context menu item")

    static let findInPage = NSLocalizedString("find.in.page", value: "%1$d of %2$d", comment: "Find in page status (e.g. 1 of 99)")

    static let moreMenuItem = NSLocalizedString("sharing.more", value: "More…", comment: "Sharing Menu -> More…")
    static let findInPageMenuItem = NSLocalizedString("find.in.page.menu.item", value: "Find in Page…", comment: "Menu item title")
    static let shareMenuItem = NSLocalizedString("share.menu.item", value: "Share", comment: "Menu item title")
    static let printMenuItem = NSLocalizedString("print.menu.item", value: "Print…", comment: "Menu item title")
    static let newWindowMenuItem = NSLocalizedString("new.window.menu.item", value: "New Window", comment: "Menu item title")
    
    static let fireproofSites = NSLocalizedString("fireproof.sites", value: "Fireproof Sites", comment: "Fireproof sites list title")
    static let fireproofCheckboxTitle = NSLocalizedString("fireproof.checkbox.title", value: "Ask to Fireproof websites when signing in", comment: "Fireproof settings checkbox title")
    static let fireproofExplanation = NSLocalizedString("fireproof.explanation", value: "Websites rely on cookies to keep you signed in. When you Fireproof a site, cookies won’t be erased and you'll stay signed in, even after using the Fire Button. We still block third-party trackers found on Fireproof websites.", comment: "Fireproofing mechanism explanation")
    static let manageFireproofSites = NSLocalizedString("fireproof.manage-sites", value: "Manage Fireproof Sites...", comment: "Fireproof settings button caption")

    static let fireDialogFireproofSites = NSLocalizedString("fire.dialog.fireproof.sites", value: "Fireproof sites won't be cleared", comment: "Category of domains in fire button dialog")
    static let fireDialogClearSites = NSLocalizedString("fire.dialog.clear.sites", value: "Selected sites will be cleared", comment: "Category of domains in fire button dialog")
    static let allData = NSLocalizedString("fire.all-sites", value: "All sites", comment: "Configuration option for fire button")
    static let currentSite = NSLocalizedString("fire.currentSite", value: "Current site", comment: "Configuration option for fire button")
    static let currentTab = NSLocalizedString("fire.currentTab", value: "All sites visited in current tab", comment: "Configuration option for fire button")
    static let currentWindow = NSLocalizedString("fire.currentWindow", value: "All sites visited in current window", comment: "Configuration option for fire button")
    static let allDataDescription = NSLocalizedString("fire.all-data.description", value: "Clear all tabs and related site data", comment: "Description of the 'All Data' configuration option for the fire button")
    static let currentWindowDescription = NSLocalizedString("fire.current-window.description", value: "Clear current window and related site data", comment: "Description of the 'Current Window' configuration option for the fire button")
    static let selectedDomainsDescription = NSLocalizedString("fire.selected-domains.description", value: "Clear selected domains and related site data", comment: "Description of the 'Current Window' configuration option for the fire button")
    static let fireDialogNothingToBurn = NSLocalizedString("fire.dialog.nothing-to-burn", value: "No data to clear", comment: "Information label to inform there is no domain for burning")
    static let fireDialogSiteIsFireproof = NSLocalizedString("fire.dialog.site-is-fireproof", value: "Nothing to clear. This is one of your Fireproof Sites.", comment: "Information label to inform that a fireproof website won't be burned")
    static let fireDialogDetails = NSLocalizedString("fire.dialog.details", value: "Details", comment: "Button to show more details")
    static let fireDialogAllTabsWillClose = NSLocalizedString("fire.dialog.all-tabs-will-close", value: "All tabs open to selected sites will close", comment: "Warning label shown in an expanded view of the fire popover")
    static let fireDialogAllUnpinnedTabsWillClose = NSLocalizedString("fire.dialog.all-unpinned-tabs-will-close", value: "All unpinned tabs open to selected sites will close", comment: "Warning label shown in an expanded view of the fire popover")
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

    static let autoconsentSettingsTitle = NSLocalizedString("autoconsent.title", value: "Cookie Consent Pop-ups", comment: "Autoconsent settings section title")
    static let autoconsentCheckboxTitle = NSLocalizedString("autoconsent.checkbox.title", value: "Let DuckDuckGo manage cookie consent pop-ups", comment: "Autoconsent settings checkbox title")
    static let autoconsentExplanation = NSLocalizedString("autoconsent.explanation", value: "When DuckDuckGo detects cookie consent pop-ups on sites you visit, we'll automatically set your cookie preferences to minimize cookies and maximize privacy, then close the pop-ups.", comment: "Autoconsent feature explanation in settings")

    static let gpcSettingsTitle = NSLocalizedString("gpc.title", value: "Global Privacy Control (GPC)", comment: "GPC settings title")
    static let gpcCheckboxTitle = NSLocalizedString("gpc.checkbox.title", value: "Enable Global Privacy Control", comment: "GPC settings checkbox title")
    static let gpcExplanation = NSLocalizedString("gpc.explanation", value: "DuckDuckGo automatically blocks many trackers. With Global Privacy Control (GPC), you can also ask participating websites to restrict selling or sharing your personal data with other companies.", comment: "GPC explanation in settings")
    static let gpcLearnMore = NSLocalizedString("gpc.learnmore.link", value: "Learn More", comment: "Learn More link")
    
    static let autofillAskToSave = NSLocalizedString("autofill.ask-to-save", value: "Ask to Save", comment: "Autofill settings section title")
    static let autofillAskToSaveExplanation = NSLocalizedString("autofill.ask-to-save.explanation", value: "Receive prompts to save new Autofill information when filling out online forms.", comment: "Description of Autofill autosaving feature - used in settings")
    static let autofillUsernamesAndPasswords = NSLocalizedString("autofill.usernames-and-passwords", value: "Usernames and passwords", comment: "Autofill autosaved data type")
    static let autofillAddresses = NSLocalizedString("autofill.addresses", value: "Addresses", comment: "Autofill autosaved data type")
    static let autofillPaymentMethods = NSLocalizedString("autofill.payment-methods", value: "Payment methods", comment: "Autofill autosaved data type")
    static let autofillAutoLock = NSLocalizedString("autofill.auto-lock", value: "Auto-lock", comment: "Autofill settings section title")
    static let autofillLockWhenIdle = NSLocalizedString("autofill.lock-when-idle", value: "Lock Autofill after computer is idle for", comment: "Autofill auto-lock setting")
    static let autofillNeverLock = NSLocalizedString("autofill.never-lock", value: "Never lock Autofill", comment: "Autofill auto-lock setting")
    static let autofillNeverLockWarning = NSLocalizedString("autofill.never-lock-warning", value: "Anyone with access to your device will be able to use and modify your Autofill data.", comment: "Autofill disabled auto-lock warning")

    static let downloadsLocation = NSLocalizedString("downloads.location", value: "Location", comment: "Downloads directory location")
    static let downloadsAlwaysAsk = NSLocalizedString("downloads.always-ask", value: "Always ask where to save files", comment: "Downloads preferences checkbox")
    static let downloadsChangeDirectory = NSLocalizedString("downloads.change", value: "Change...", comment: "Change downloads directory button")

    static let passwordManagement = NSLocalizedString("passsword.management", value: "Autofill", comment: "Used as title for password management user interface")
    static let passwordManagementAllItems = NSLocalizedString("passsword.management.all-items", value: "All Items", comment: "Used as title for the Autofill All Items option")
    static let passwordManagementLogins = NSLocalizedString("passsword.management.logins", value: "Logins", comment: "Used as title for the Autofill Logins option")
    static let passwordManagementIdentities = NSLocalizedString("passsword.management.identities", value: "Identities", comment: "Used as title for the Autofill Identities option")
    static let passwordManagementCreditCards = NSLocalizedString("passsword.management.credit-cards", value: "Credit Cards", comment: "Used as title for the Autofill Credit Cards option")
    static let passwordManagementNotes = NSLocalizedString("passsword.management.notes", value: "Notes", comment: "Used as title for the Autofill Notes option")
    static let passwordManagementLock = NSLocalizedString("passsword.management.lock", value: "Lock", comment: "Lock Logins Vault menu")
    static let passwordManagementUnlock = NSLocalizedString("passsword.management.unlock", value: "Unlock", comment: "Unlock Logins Vault menu")

    static let importBrowserData = NSLocalizedString("import.browser.data", value: "Import Bookmarks and Passwords…", comment: "Opens Import Browser Data dialog")

    static let bookmarks = NSLocalizedString("bookmarks", value: "Bookmarks", comment: "Button for bookmarks")
    static let bookmarksOpenInNewTabs = NSLocalizedString("bookmarks.open.in.new.tabs", value: "Open in New Tabs", comment: "Open all bookmarks in folder in new tabs")
    static let addToFavorites = NSLocalizedString("add.to.favorites", value: "Add to Favorites", comment: "Button for adding bookmarks to favorites")
    static let addFavorite = NSLocalizedString("add.favorite", value: "Add Favorite", comment: "Button for adding a favorite bookmark")
    static let editFavorite = NSLocalizedString("edit.favorite", value: "Edit Favorite", comment: "Header of the view that edits a favorite bookmark")
    static let editFolder = NSLocalizedString("edit.folder", value: "Edit Folder", comment: "Header of the view that edits a bookmark folder")
    static let removeFromFavorites = NSLocalizedString("remove.from.favorites", value: "Remove from Favorites", comment: "Button for removing bookmarks from favorites")
    static let bookmarkThisPage = NSLocalizedString("bookmark.this.page", value: "Bookmark This Page", comment: "Menu item for bookmarking current page")

    static let zoom = NSLocalizedString("zoom", value: "Zoom", comment: "Menu with Zooming commands")

    static let emailOptionsMenuItem = NSLocalizedString("email.optionsMenu", value: "Email Protection", comment: "Menu item email feature")
    static let emailOptionsMenuCreateAddressSubItem = NSLocalizedString("email.optionsMenu.createAddress", value: "Generate Private Duck Address", comment: "Create an email alias sub menu item")
    static let emailOptionsMenuTurnOffSubItem = NSLocalizedString("email.optionsMenu.turnOff", value: "Disable Email Protection", comment: "Disable email sub menu item")
    static let emailOptionsMenuTurnOnSubItem = NSLocalizedString("email.optionsMenu.turnOn", value: "Enable Email Protection", comment: "Enable email sub menu item")
    static let privateEmailCopiedToClipboard = NSLocalizedString("email.copied", value: "New address copied to your clipboard", comment: "Private email address was copied to clipboard message")

    static let newFolder = NSLocalizedString("folder.optionsMenu.newFolder", value: "New Folder", comment: "Option for creating a new folder")
    static let renameFolder = NSLocalizedString("folder.optionsMenu.renameFolder", value: "Rename Folder", comment: "Option for renaming a folder")
    static let deleteFolder = NSLocalizedString("folder.optionsMenu.deleteFolder", value: "Delete Folder", comment: "Option for deleting a folder")
    
    static let updateBookmark = NSLocalizedString("bookmark.update", value: "Update Bookmark", comment: "Option for updating a bookmark")

    static let failedToOpenExternally = NSLocalizedString("open.externally.failed", value: "The app required to open that link can’t be found", comment: "’Link’ is link on a website")

    static let devicePermissionAuthorizationFormat = NSLocalizedString("permission.authorization.format",
                                                                       value: "Allow “%@“ to use your %@?",
                                                                       comment: "Popover asking for domain %@ to use camera/mic/location (%@)")
    static let popupWindowsPermissionAuthorizationFormat = NSLocalizedString("permission.authorization.popups",
                                                                             value: "Allow “%@“ to open PopUp Window?",
                                                                             comment: "Popover asking for domain %@ to open Popup Window")
    static let permissionMenuHeaderPopupWindowsFormat = NSLocalizedString("permission.authorization.popups",
                                                                          value: "Allow “%@“ to open PopUp Windows?",
                                                                          comment: "Popover asking for domain %@ to open Popup Window")
    static let externalSchemePermissionAuthorizationFormat = NSLocalizedString("permission.authorization.externalScheme.format",
                                                                               value: "“%@” would like to open this link in %@",
                                                                               comment: "Popover asking for domain %@ to open link in External App (%@)")

    static let permissionMicrophone = NSLocalizedString("permission.microphone", value: "Microphone", comment: "Microphone input media device name")
    static let permissionCamera = NSLocalizedString("permission.camera", value: "Camera", comment: "Camera input media device name")
    static let permissionCameraAndMicrophone = NSLocalizedString("permission.cameraAndmicrophone", value: "Camera and Microphone", comment: "camera and microphone input media devices name")
    static let permissionGeolocation = NSLocalizedString("permission.geolocation", value: "Location", comment: "User's Geolocation permission access name")
    static let permissionPopups = NSLocalizedString("permission.popups", value: "Pop-ups", comment: "Open Pop Up Windows permission access name")

    static let permissionMuteFormat = NSLocalizedString("permission.mute", value: "Pause %@ use on “%@”", comment: "Temporarily pause input media device %@ access for %@2 website")
    static let permissionUnmuteFormat = NSLocalizedString("permission.unmute", value: "Resume %@ use on “%@”", comment: "Resume input media device %@ access for %@ website")
    static let permissionReloadToEnable = NSLocalizedString("permission.reloadPage", value: "Reload to ask permission again", comment: "Reload webpage to ask for input media device access permission again")

    static let permissionAllowExternalSchemeFormat = NSLocalizedString("permission.allow.externalScheme", value: "Allow “%@“ to open %@", comment: "Allow to open External Link (%@ 2) to open on current domain (%@ 1)")
    static let permissionMenuHeaderExternalSchemeFormat = NSLocalizedString("permission.allow.externalScheme", value: "Allow the %@ to open “%@” links", comment: "Allow the App Name(%@ 1) to open “URL Scheme”(%@ 2) links")

    static let permissionAppPermissionDisabledFormat = NSLocalizedString("permission.disabled.app", value: "%@ access is disabled for %@", comment: "The app (DuckDuckGo: %@ 2) has no access permission to (%@ 1) media device")
    static let permissionGeolocationServicesDisabled = NSLocalizedString("permission.disabled.system", value: "System location services are disabled", comment: "Geolocation Services are disabled in System Preferences")
    static let permissionOpenSystemPreferences = NSLocalizedString("permission.open.preferences", value: "Open System Preferences", comment: "Open System Preferences (to re-enable permission for the App)")

    static let permissionPopupTitle = NSLocalizedString("permission.popup.title", value: "Blocked Pop-ups", comment: "List of blocked popups Title")
    static let permissionPopupOpenFormat = NSLocalizedString("permission.popup.open.format", value: "%@", comment: "Open %@ URL Pop-up")

    static let permissionExternalSchemeOpenFormat = NSLocalizedString("permission.externalScheme.open.format", value: "Open %@", comment: "Open %@ App Name")

    static let privacyDashboardPermissionAsk = NSLocalizedString("dashboard.permission.ask", value: "Ask every time", comment: "Privacy Dashboard: Website should always Ask for permission for input media device access")
    static let privacyDashboardPermissionAlwaysAllow = NSLocalizedString("dashboard.permission.allow", value: "Always allow", comment: "Privacy Dashboard: Website can always access input media device")
    static let privacyDashboardPermissionAlwaysDeny = NSLocalizedString("dashboard.permission.deny", value: "Always deny", comment: "Privacy Dashboard: Website can never access input media device")
    static let permissionPopoverDenyButton = NSLocalizedString("permission.popover.deny", value: "Deny", comment: "Permission Popover: Deny Website input media device access")

    static let privacyDashboardPopupsAlwaysAsk = NSLocalizedString("dashboard.popups.ask", value: "Notify", comment: "Make PopUp Windows always asked from user for current domain")

    static let settings = NSLocalizedString("settings", value: "Settings", comment: "Menu item for opening settings")

    static let general = NSLocalizedString("preferences.general", value: "General", comment: "Show general preferences")
    static let defaultBrowser = NSLocalizedString("preferences.default-browser", value: "Default Browser", comment: "Show default browser preferences")
    static let appearance = NSLocalizedString("preferences.appearance", value: "Appearance", comment: "Show appearance preferences")
    static let privacy = NSLocalizedString("preferences.privacy", value: "Privacy", comment: "Show privacy browser preferences")
    static let about = NSLocalizedString("preferences.about", value: "About", comment: "Show about screen")

    static let downloads = NSLocalizedString("preferences.downloads", value: "Downloads", comment: "Show downloads browser preferences")
    static let isDefaultBrowser = NSLocalizedString("preferences.default-browser.active", value: "DuckDuckGo is your default browser", comment: "Indicate that the browser is the default")
    static let isNotDefaultBrowser = NSLocalizedString("preferences.default-browser.inactive", value: "DuckDuckGo is not your default browser.", comment: "Indicate that the browser is not the default")
    static let makeDefaultBrowser = NSLocalizedString("preferences.default-browser.button.make-default", value: "Make DuckDuckGo Default...", comment: "")
    static let onStartup = NSLocalizedString("preferences.on-startup", value: "On Startup", comment: "Name of the preferences section related to app startup")
    static let reopenAllWindowsFromLastSession = NSLocalizedString("preferences.reopen-windows", value: "Reopen all windows from last session", comment: "Option to control session restoration")
    static let theme = NSLocalizedString("preferences.appearance.theme", value: "Theme", comment: "Theme preferences")
    static let addressBar = NSLocalizedString("preferences.appearance.address-bar", value: "Address Bar", comment: "Theme preferences")
    static let showFullWebsiteAddress = NSLocalizedString("preferences.appearance.show-full-url", value: "Show full website address", comment: "Option to show full URL in the address bar")
    static let showAutocompleteSuggestions = NSLocalizedString("preferences.appearance.show-autocomplete-suggestions", value: "Show autocomplete suggestions", comment: "Option to show autocomplete suggestions in the address bar")
    static let autofill = NSLocalizedString("preferences.autofill", value: "Autofill", comment: "Show Autofill preferences")
    
    static let aboutDuckDuckGo = NSLocalizedString("preferences.about.about-duckduckgo", value: "About DuckDuckGo", comment: "About screen")
    static let privacySimplified = NSLocalizedString("preferences.about.privacy-simplified", value: "Privacy, simplified.", comment: "About screen")

    static func moreAt(url: String) -> String {
        let localized = NSLocalizedString("preferences.about.more-at", value: "More at %@", comment: "Link to the about page")
        return String(format: localized, url)
    }

    static let sendFeedback = NSLocalizedString("preferences.about.send-feedback", value: "Send Feedback", comment: "Feedback button in the about preferences page")

    static let feedbackBreakageDisclaimer = NSLocalizedString("feedback.breakage.disclaimer", value: "Reports sent to DuckDuckGo are 100% anonymous and only include your selection above, your optional message, the URL, a list of trackers we found on the site, the DuckDuckGo app version, and your macOS version.", comment: "Disclaimer in breakage form")
    static let feedbackDisclaimer = NSLocalizedString("feedback.disclaimer", value: "Reports sent to DuckDuckGo are 100% anonymous and only include your message, the DuckDuckGo app version, and your macOS version.", comment: "Disclaimer in breakage form")
    
    static let feedbackBugDescription = NSLocalizedString("feedback.bug.description", value: "Please describe the problem in as much detail as possible:", comment: "Label in the feedback form")
    static let feedbackFeatureRequestDescription = NSLocalizedString("feedback.feature.request.description", value: "What feature would you like to see?", comment: "Label in the feedback form")
    static let feedbackOtherDescription = NSLocalizedString("feedback.other.description", value: "Please give us your feedback:", comment: "Label in the feedback form")

    static func versionLabel(version: String, build: String) -> String {
        let localized = NSLocalizedString("version",
                                          value: "Version %@ (%@)",
                                          comment: "Displays the version and build numbers")
        return String(format: localized, version, build)
    }

    static let privacyPolicy = NSLocalizedString("preferences.about.privacy-policy", value: "Privacy Policy", comment: "Link to privacy policy page")

    // MARK: - Login Import & Export

    static let importLoginsCSV = NSLocalizedString("import.logins.csv.title", value: "CSV Logins File", comment: "Title text for the CSV importer")
    static let importBookmarksHTML = NSLocalizedString("import.bookmarks.html.title", value: "HTML Bookmarks File", comment: "Title text for the HTML Bookmarks importer")
    static let importBookmarksSelectHTMLFile = NSLocalizedString("import.bookmarks.select-html-file", value: "Select HTML Bookmarks File…", comment: "Button text for selecting HTML Bookmarks file")
    static let importBookmarksSelectAnotherFile = NSLocalizedString("import.bookmarks.select-another-file", value: "Select Another HTML File…", comment: "Button text for selecting another file")
    static let importBookmarksFailedToReadHTMLFile = NSLocalizedString("import.bookmarks.failed-to-read-file", value: "Failed to read HTML file", comment: "Error text when importing a HTML file")

    static func importingFile(validBookmarks: Int) -> String {
        let localized = NSLocalizedString("import.bookmarks.html.valid-bookmarks",
                                          value: "Contains %@ bookmarks",
                                          comment: "Displays the number of the bookmarks being imported")
        return String(format: localized, String(validBookmarks))
    }

    static let csvImportDescription = NSLocalizedString("import.logins.csv.description", value: "The CSV importer will try to match column headers to their position.\nIf there is no header, it supports two formats:\n\n1. URL, Username, Password\n2. Title, URL, Username, Password", comment: "Description text for the CSV importer")
    static let importLoginsSelectCSVFile = NSLocalizedString("import.logins.select-csv-file", value: "Select CSV File…", comment: "Button text for selecting a CSV file")
    static let importLoginsSelectSafariCSVFile = NSLocalizedString("import.logins.select-safari-csv-file", value: "Select Passwords CSV File…", comment: "Button text for selecting a Safari CSV file")
    static let importLoginsSelect1PasswordCSVFile = NSLocalizedString("import.logins.select-1password-csv-file", value: "Select 1Password CSV File…", comment: "Button text for selecting a 1Password CSV file")
    static let importLoginsSelectLastPassCSVFile = NSLocalizedString("import.logins.select-lastpass-csv-file", value: "Select LastPass CSV File…", comment: "Button text for selecting a LastPass CSV file")

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

    static let dataImportFailedTitle = NSLocalizedString("import.data.import-failed.title", value: "Sorry, we weren't able to import your data.", comment: "Alert title when the data import fails")

    static let dataImportSubmitFeedback = NSLocalizedString("import.data.submit-feedback", value: "submit feedback", comment: "Link text used in the data import failure alert")
    static let dataImportFailedBody = NSLocalizedString("import.data.import-failed.body",
                                                        value: "Please submit feedback so we can address this issue.",
                                                        comment: "Alert body text used in the data import failure alert")

    static let dataImportAlertImport = NSLocalizedString("import.data.alert.import", value: "Import", comment: "Import button for data import alerts")
    static let dataImportAlertAccept = NSLocalizedString("import.data.alert.accept", value: "Okay", comment: "Accept button for data import alerts")
    static let dataImportAlertCancel = NSLocalizedString("import.data.alert.cancel", value: "Cancel", comment: "Cancel button for data import alerts")

    static func dataImportRequiresPasswordTitle(_ source: DataImport.Source) -> String {
        let localized = NSLocalizedString("import.data.requires-password.title",
                                         value: "Enter Primary Password for %@",
                                         comment: "Alert title text when the data import needs a password")
        return String(format: localized, source.importSourceName)
    }

    static func dataImportRequiresPasswordBody(_ source: DataImport.Source) -> String {
        let localized = NSLocalizedString("import.data.requires-password.body",
                                          value: "DuckDuckGo won't save or share your %1$@ Primary Password, but DuckDuckGo needs it to access and import passwords from %1$@.",
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
    static let bookmarkImportImportedFavorites = NSLocalizedString("import.bookmarks.folder.imported-favorites", value: "Imported Favorites", comment: "Title text for Imported Favorites import folder")

    static let bookmarkImportBookmarks = NSLocalizedString("import.bookmarks.bookmarks", value: "Bookmarks", comment: "Title text for the Bookmarks import option")
    static let bookmarkImportBookmarksAndFavorites = NSLocalizedString("import.bookmarks.bookmarks-and-favorites", value: "Bookmarks & Favorites", comment: "Title text for the Bookmarks & Favorites import option")

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
    static let exportLoginsWarning = NSLocalizedString("export.logins.warning", value: "This file contains your passwords in plain text and should be saved in a secure location and deleted when you are done.\nAnyone with access to this file will be able to read your passwords.", comment: "Warning text presented when exporting logins.")

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

    static let importFromFirefoxMoreInfo = NSLocalizedString("import.from.firefox.info", value: "You'll be asked to enter your Primary Password for Firefox.\n\nImported passwords are encrypted and only stored on this computer.", comment: "More info when importing from Firefox")

    static let moreOrLessCollapse = NSLocalizedString("more.or.less.collapse", value: "Show Less", comment: "For collapsing views to show less.")
    static let moreOrLessExpand = NSLocalizedString("more.or.less.expand", value: "Show More", comment: "For expanding views to show more.")

    static let defaultBrowserPromptMessage = NSLocalizedString("default.browser.prompt.message", value: "Make DuckDuckGo your default browser", comment: "")
    static let defaultBrowserPromptButton = NSLocalizedString("default.browser.prompt.button", value: "Set Default...", comment: "")

    static let homePageProtectionSummaryInfo = NSLocalizedString("home.page.protection.summary.info", value: "No recent activity", comment: "")
    static func homePageProtectionSummaryMessage(numberOfTrackersBlocked: Int) -> String {
        let localized = NSLocalizedString("home.page.protection.summary.info",
                                          value: "%@ tracking attempts blocked",
                                          comment: "")
        return String(format: localized, NumberFormatter.localizedString(from: NSNumber(value: numberOfTrackersBlocked), number: .decimal))
    }
    static let homePageProtectionDurationInfo = NSLocalizedString("home.page.protection.duration", value: "PAST 7 DAYS", comment: "Past 7 days in uppercase.")

    static let homePageEmptyStateItemTitle = NSLocalizedString("home.page.empty.state.item.title", value: "Recently visited sites appear here", comment: "")
    static let homePageEmptyStateItemMessage = NSLocalizedString("home.page.empty.state.item.message", value: "Keep browsing to see how many trackers were blocked", comment: "")
    static let homePageNoTrackersFound = NSLocalizedString("home.page.no.trackers.found", value: "No trackers found", comment: "")
    static let homePageNoTrackersBlocked = NSLocalizedString("home.page.no.trackers.blocked", value: "No trackers blocked", comment: "")
    static let homePageBurnFireproofSiteAlert = NSLocalizedString("home.page.burn.fireproof.site.alert", value: "History will be cleared for this site, but related data will remain, because this site is Fireproof", comment: "Message for an alert displayed when trying to burn a fireproof website")
    static let homePageClearHistory = NSLocalizedString("home.page.clear.history", value: "Clear History", comment: "Button caption for the burn fireproof website alert")

    static let tooltipAddToFavorites = NSLocalizedString("tooltip.addToFavorites", value: "Add to Favorites", comment: "Tooltip for add to favorites button")

    static func tooltipClearHistoryAndData(domain: String) -> String {
        let localized = NSLocalizedString("tooltip.clearHistoryAndData",
                                          value: "Clear browsing history and data for %@",
                                          comment: "Tooltip for burn button")
        return String(format: localized, domain)
    }
    static func tooltipClearHistory(domain: String) -> String {
        let localized = NSLocalizedString("tooltip.clearHistory",
                                          value: "Clear browsing history for %@",
                                          comment: "Tooltip for burn button")
        return String(format: localized, domain)
    }

    static let recentlyClosedMenuItemSuffixOne = NSLocalizedString("one.more.tab", value: " (and 1 more tab)", comment: "suffix of string in Recently Closed menu")
    static let recentlyClosedMenuItemSuffixMultiple = NSLocalizedString("n.more.tabs", value: " (and %d more tabs)", comment: "suffix of string in Recently Closed menu")

    static let reopenLastClosedTab = NSLocalizedString("reopen.last.closed.tab", value: "Reopen Last Closed Tab", comment: "")
    static let reopenLastClosedWindow = NSLocalizedString("reopen.last.closed.window", value: "Reopen Last Closed Window", comment: "")
    static let cookiesManagedNotification = NSLocalizedString("notification.badge.cookiesmanaged", value: "Cookies Managed", comment: "Notification that appears when browser automatically handle cookies")

    static let autoconsentModalTitle = NSLocalizedString("autoconsent.modal.title", value: "Looks like this site has a cookie consent pop-up 👇", comment: "Title for modal asking the user to auto manage cookies")
    
    static let autoconsentModalBody = NSLocalizedString("autoconsent.modal.body", value: "Want me to handle these for you? I can try to minimize cookies, maximize privacy, and hide pop-ups like these.", comment: "Body for modal asking the user to auto manage cookies")
   
    static let autoconsentModalConfirmButton = NSLocalizedString("autoconsent.modal.cta.confirm", value: "Manage Cookie Pop-ups", comment: "Confirm button for modal asking the user to auto manage cookies")
    static let autoconsentModalDenyButton = NSLocalizedString("autoconsent.modal.cta.deny", value: "No Thanks", comment: "Deny button for modal asking the user to auto manage cookies")

    static let clearAllHistoryMenuItem = NSLocalizedString("history.menu.clear.all.history", value: "Clear All History…", comment: "Menu item to clear all history")
    static let clearThisHistoryMenuItem = NSLocalizedString("history.menu.clear.this.history", value: "Clear This History…", comment: "Menu item to clear parts of history and data")
    static let recentlyVisitedMenuSection = NSLocalizedString("history.menu.recently.visited", value: "Recently Visited", comment: "Section header of the history menu")
    static let olderMenuItem = NSLocalizedString("history.menu.older", value: "Older…", comment: "Menu item representing older history")

    static let clearAllDataQuestion = NSLocalizedString("history.menu.clear.all.history.question", value: "Clear all history and \nclose all tabs?", comment: "Alert with the confirmation to clear all history and data")
    static let clearAllDataDescription = NSLocalizedString("history.menu.clear.all.history.description", value: "Cookies and site data for all sites will also be cleared, unless the site is Fireproof.", comment: "Description in the alert with the confirmation to clear all data")

    static let clearDataHeader = NSLocalizedString("history.menu.clear.data.question", value: "Clear History for %@?", comment: "Alert with the confirmation to clear all data")
    static let clearDataDescription = NSLocalizedString("history.menu.clear.data.description", value: "Cookies and other data for sites visited on this day will also be cleared unless the site is Fireproof. History from other days will not be cleared.", comment: "Description in the alert with the confirmation to clear browsing history")
    static let clearDataTodayHeader = NSLocalizedString("history.menu.clear.data.today.question", value: "Clear history for today \nand close all tabs?", comment: "Alert with the confirmation to clear all data")
    static let clearDataTodayDescription = NSLocalizedString("history.menu.clear.data.today.description", value: "Cookies and other data for sites visited today will also be cleared unless the site is Fireproof. History from other days will not be cleared.", comment: "Description in the alert with the confirmation to clear browsing history")

    static let showBookmarksBar = NSLocalizedString("bookmarks.bar.show", value: "Show Bookmarks Bar", comment: "Menu item for showing the bookmarks bar")
    static let hideBookmarksBar = NSLocalizedString("bookmarks.bar.hide", value: "Hide Bookmarks Bar", comment: "Menu item for hiding the bookmarks bar")
    static let bookmarksBarFolderEmpty = NSLocalizedString("bookmarks.bar.folder.empty", value: "Empty", comment: "Empty state for a bookmarks bar folder")
    static let bookmarksBarContextMenuCopy = NSLocalizedString("bookmarks.bar.context-menu.copy", value: "Copy", comment: "Copy menu item for the bookmarks bar context menu")
    static let bookmarksBarContextMenuDelete = NSLocalizedString("bookmarks.bar.context-menu.delete", value: "Delete", comment: "Delete menu item for the bookmarks bar context menu")
    static let bookmarksBarContextMenuMoveToEnd = NSLocalizedString("bookmarks.bar.context-menu.move-to-end", value: "Move to End", comment: "Move to End menu item for the bookmarks bar context menu")
    
}
