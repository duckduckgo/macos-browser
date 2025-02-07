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
import Navigation
import BrowserServicesKit

struct UserText {

    static let duckDuckGo = NSLocalizedString("about.app_name", value: "DuckDuckGo", comment: "Application name to be displayed in the About dialog")
    static let duckDuckGoForMacAppStore = NSLocalizedString("about.app_name_app_store", value: "DuckDuckGo for Mac App Store", comment: "Application name to be displayed in the About dialog in App Store app")

    // MARK: - Dialogs
    static let ok = NSLocalizedString("ok", value: "OK", comment: "OK button")
    static let cancel = NSLocalizedString("cancel", value: "Cancel", comment: "Cancel button")
    static let notNow = NSLocalizedString("notnow", value: "Not Now", comment: "Not Now button")
    static let remove = NSLocalizedString("generic.remove.button", value: "Remove", comment: "Label of a button that allows the user to remove an item")
    static let delete = NSLocalizedString("generic.delete.button", value: "Delete", comment: "Label of a button that allows the user to delete an item")
    static let discard = NSLocalizedString("generic.discard.button", value: "Discard", comment: "Label of a button that allows the user discard an action/change")
    static let neverForThisSite = NSLocalizedString("never.for.this.site", value: "Never Ask for This Site", comment: "Never ask to save login credentials for this site button")
    static let open = NSLocalizedString("open", value: "Open", comment: "Open button")
    static let close = NSLocalizedString("close", value: "Close", comment: "Close button")
    static let dontClose = NSLocalizedString("dont.close", value: "Don’t Close", comment: "Don’t Close the window button title")
    static let save = NSLocalizedString("save", value: "Save", comment: "Save button")
    static let dontSave = NSLocalizedString("dont.save", value: "Don't Save", comment: "Don't Save button")
    static let update = NSLocalizedString("update", value: "Update", comment: "Update button")
    static let dontUpdate = NSLocalizedString("dont.update", value: "Don't Update", comment: "Don't Update button")
    static let copy = NSLocalizedString("copy", value: "Copy", comment: "Copy button")
    static let details = NSLocalizedString("details", value: "Details", comment: "details button")
    static let submit = NSLocalizedString("submit", value: "Submit", comment: "Submit button")
    static let submitReport = NSLocalizedString("submit.report", value: "Submit Report", comment: "Submit Report button")
    static let pasteFromClipboard = NSLocalizedString("paste-from-clipboard", value: "Paste from Clipboard", comment: "Paste button")
    static let edit = NSLocalizedString("edit", value: "Edit", comment: "Edit button")
    static let gotIt = NSLocalizedString("got.it", value: "Got It!", comment: "Got it button")
    static let copySelection = NSLocalizedString("copy-selection", value: "Copy", comment: "Copy selection menu item")
    static let deleteBookmark = NSLocalizedString("delete-bookmark", value: "Delete Bookmark", comment: "Delete Bookmark button")
    static let removeFavorite = NSLocalizedString("remove-favorite", value: "Remove Favorite", comment: "Remove Favorite button")
    static let quit = NSLocalizedString("quit", value: "Quit", comment: "Quit button")
    static let uninstall = NSLocalizedString("uninstall", value: "Uninstall", comment: "Uninstall button")
    static let dontQuit = NSLocalizedString("dont.quit", value: "Don’t Quit", comment: "Don’t Quit button")
    static let next = NSLocalizedString("next", value: "Next", comment: "Next button")
    static let pasteAndGo = NSLocalizedString("paste.and.go", value: "Paste & Go", comment: "Paste & Go button")
    static let pasteAndSearch = NSLocalizedString("paste.and.search", value: "Paste & Search", comment: "Paste & Search button")
    static let clear = NSLocalizedString("clear", value: "Clear", comment: "Clear button")
    static let clearAndQuit = NSLocalizedString("clear.and.quit", value: "Clear and Quit", comment: "Button to clear data and quit the application")
    static let quitWithoutClearing = NSLocalizedString("quit.without.clearing", value: "Quit Without Clearing", comment: "Button to quit the application without clearing data")
    static let `continue` = NSLocalizedString("`continue`", value: "Continue", comment: "Continue button")
    static let bookmarkDialogAdd = NSLocalizedString("bookmark.dialog.add", value: "Add", comment: "Button to confim a bookmark creation")
    static let newFolderDialogAdd = NSLocalizedString("folder.dialog.add", value: "Add", comment: "Button to confim a bookmark folder creation")
    static let doneDialog = NSLocalizedString("done", value: "Done", comment: "Done button")

    static func openIn(value: String) -> String {
        let localized = NSLocalizedString("open.in",
                                          value: "Open in %@",
                                          comment: "Opening an entity in other application")
        return String(format: localized, value)
    }

    // MARK: - Main Menu -> DuckDuckGo
    static let mainMenuAppPreferences = NSLocalizedString("main-menu.app.preferences", value: "Preferences…", comment: "Main Menu DuckDuckGo item")
    static let mainMenuAppServices = NSLocalizedString("main-menu.app.services", value: "Services", comment: "Main Menu DuckDuckGo item")
    static let mainMenuAppCheckforUpdates = NSLocalizedString("main-menu.app.check-for-updates", value: "Check for Updates…", comment: "Main Menu DuckDuckGo item")
    static let mainMenuAppHideDuckDuckGo = NSLocalizedString("main-menu.app.hide-duck-duck-go", value: "Hide DuckDuckGo", comment: "Main Menu DuckDuckGo item")
    static let mainMenuAppHideOthers = NSLocalizedString("main-menu.app.hide-others", value: "Hide Others", comment: "Main Menu DuckDuckGo item")
    static let mainMenuAppShowAll = NSLocalizedString("main-menu.app.show-all", value: "Show All", comment: "Main Menu DuckDuckGo item")
    static let mainMenuAppQuitDuckDuckGo = NSLocalizedString("main-menu.app.quit-duck-duck-go", value: "Quit DuckDuckGo", comment: "Main Menu DuckDuckGo item")

    // MARK: - Main Menu -> -File
    static let mainMenuFile = NSLocalizedString("main-menu.file", value: "File", comment: "Main Menu File")
    static let mainMenuFileNewTab = NSLocalizedString("main-menu.file.new-tab", value: "New Tab", comment: "Main Menu File item")
    static let mainMenuFileOpenLocation = NSLocalizedString("main-menu.file.open-location", value: "Open Location…", comment: "Main Menu File item- Menu option that allows the user to connect to an address (type an address) on click the address bar of the browser is selected and the user can type.")
    static let mainMenuFileCloseWindow = NSLocalizedString("main-menu.file.close-window", value: "Close Window", comment: "Main Menu File item")
    static let mainMenuFileCloseAllWindows = NSLocalizedString("main-menu.file.close-all-windows", value: "Close All Windows", comment: "Main Menu File item")
    static let mainMenuFileSaveAs = NSLocalizedString("main-menu.file.save-as", value: "Save As…", comment: "Main Menu File item")
    static let mainMenuFileImportBookmarksandPasswords = NSLocalizedString("main-menu.file.import-bookmarks-and-passwords", value: "Import Bookmarks and Passwords…", comment: "Main Menu File item")
    static let mainMenuFileExport = NSLocalizedString("main-menu.file.export", value: "Export", comment: "Main Menu File item")
    static let mainMenuFileExportPasswords = NSLocalizedString("main-menu.file.export-passwords", value: "Passwords…", comment: "Main Menu File-Export item")
    static let mainMenuFileExportBookmarks = NSLocalizedString("main-menu.file.export-bookmarks", value: "Bookmarks…", comment: "Main Menu File-Export item")

    // MARK: - Main Menu -> Edit
    static let mainMenuEdit = NSLocalizedString("main-menu.edit", value: "Edit", comment: "Main Menu Edit")
    static let mainMenuEditUndo = NSLocalizedString("main-menu.edit.undo", value: "Undo", comment: "Main Menu Edit item")
    static let mainMenuEditRedo = NSLocalizedString("main-menu.edit.redo", value: "Redo", comment: "Main Menu Edit item")
    static let mainMenuEditCut = NSLocalizedString("main-menu.edit.cut", value: "Cut", comment: "Main Menu Edit item")
    static let mainMenuEditCopy = NSLocalizedString("main-menu.edit.copy", value: "Copy", comment: "Main Menu Edit item")
    static let mainMenuEditPaste = NSLocalizedString("main-menu.edit.paste", value: "Paste", comment: "Main Menu Edit item")
    static let mainMenuEditPasteAndMatchStyle = NSLocalizedString("main-menu.edit.paste-and-match-style", value: "Paste and Match Style", comment: "Main Menu Edit item - Action that allows the user to paste copy into a target document and the target document's style will be retained (instead of the source style)")
    static let mainMenuEditDelete = NSLocalizedString("main-menu.edit.delete", value: "Delete", comment: "Main Menu Edit item")
    static let mainMenuEditSelectAll = NSLocalizedString("main-menu.edit.select-all", value: "Select All", comment: "Main Menu Edit item")

    static let mainMenuEditFind = NSLocalizedString("main-menu.edit.find", value: "Find", comment: "Main Menu Edit item")

    // MARK: Main Menu -> Edit -> Find
    static let mainMenuEditFindFindNext = NSLocalizedString("main-menu.edit.find.find-next", value: "Find Next", comment: "Main Menu Edit-Find item")
    static let mainMenuEditFindFindPrevious = NSLocalizedString("main-menu.edit.find.find-previous", value: "Find Previous", comment: "Main Menu Edit-Find item")
    static let mainMenuEditFindHideFind = NSLocalizedString("main-menu.edit.find.hide-find", value: "Hide Find", comment: "Main Menu Edit-Find item")

    static let mainMenuEditSpellingandGrammar = NSLocalizedString("main-menu.edit.edit-spelling-and-grammar", value: "Spelling and Grammar", comment: "Main Menu Edit item")

    // MARK: Main Menu -> Edit -> Spellingand
    static let mainMenuEditSpellingandShowSpellingandGrammar = NSLocalizedString("main-menu.edit.spelling-and.show-spelling-and-grammar", value: "Show Spelling and Grammar", comment: "Main Menu Edit-Spellingand item")
    static let mainMenuEditSpellingandCheckDocumentNow = NSLocalizedString("main-menu.edit.spelling-and.check-document-now", value: "Check Document Now", comment: "Main Menu Edit-Spellingand item")
    static let mainMenuEditSpellingandCheckSpellingWhileTyping = NSLocalizedString("main-menu.edit.spelling-and.check-spelling-while-typing", value: "Check Spelling While Typing", comment: "Main Menu Edit-Spellingand item")
    static let mainMenuEditSpellingandCheckGrammarWithSpelling = NSLocalizedString("main-menu.edit.spelling-and.check-grammar-with-spelling", value: "Check Grammar With Spelling", comment: "Main Menu Edit-Spellingand item")
    static let mainMenuEditSpellingandCorrectSpellingAutomatically = NSLocalizedString("main-menu.edit.spelling-and.correct-spelling-automatically", value: "Correct Spelling Automatically", comment: "Main Menu Edit-Spellingand item")

    static let mainMenuEditSubstitutions = NSLocalizedString("main-menu.edit.subsitutions", value: "Substitutions", comment: "Main Menu Edit item")
// TODO: Done till here
    // MARK: Main Menu -> Edit -> Substitutions
    static let mainMenuEditSubstitutionsShowSubstitutions = NSLocalizedString("Show Substitutions", comment: "Main Menu Edit-Substitutions item")
    static let mainMenuEditSubstitutionsSmartCopyPaste = NSLocalizedString("Smart Copy/Paste", comment: "Main Menu Edit-Substitutions item")
    static let mainMenuEditSubstitutionsSmartQuotes = NSLocalizedString("Smart Quotes", comment: "Main Menu Edit-Substitutions item")
    static let mainMenuEditSubstitutionsSmartDashes = NSLocalizedString("Smart Dashes", comment: "Main Menu Edit-Substitutions item")
    static let mainMenuEditSubstitutionsSmartLinks = NSLocalizedString("Smart Links", comment: "Main Menu Edit-Substitutions item")
    static let mainMenuEditSubstitutionsDataDetectors = NSLocalizedString("Data Detectors", comment: "Main Menu Edit-Substitutions item")
    static let mainMenuEditSubstitutionsTextReplacement = NSLocalizedString("Text Replacement", comment: "Main Menu Edit-Substitutions item")

    static let mainMenuEditTransformations = NSLocalizedString("Transformations", comment: "Main Menu Edit item")

    // MARK: Main Menu -> Edit -> Transformations
    static let mainMenuEditTransformationsMakeUpperCase = NSLocalizedString("Make Upper Case", comment: "Main Menu Edit-Transformations item")
    static let mainMenuEditTransformationsMakeLowerCase = NSLocalizedString("Make Lower Case", comment: "Main Menu Edit-Transformations item")
    static let mainMenuEditTransformationsCapitalize = NSLocalizedString("Capitalize", comment: "Main Menu Edit-Transformations item")

    static let mainMenuEditSpeech = NSLocalizedString("Speech", comment: "Main Menu Edit item")

    // MARK: Main Menu -> Edit -> Speech
    static let mainMenuEditSpeechStartSpeaking = NSLocalizedString("Start Speaking", comment: "Main Menu Edit-Speech item")
    static let mainMenuEditSpeechStopSpeaking = NSLocalizedString("Stop Speaking", comment: "Main Menu Edit-Speech item")

    // MARK: - Main Menu -> View
    static let mainMenuView = NSLocalizedString("View", comment: "Main Menu View")
    static let mainMenuViewStop = NSLocalizedString("Stop", comment: "Main Menu View item")
    static let mainMenuViewReloadPage = NSLocalizedString("Reload Page", comment: "Main Menu View item")
    static let mainMenuViewHome = NSLocalizedString("Home", comment: "Main Menu View item")
    static let mainMenuHomeButton = NSLocalizedString("Home Button", comment: "Main Menu > View > Home Button item")

    static func mainMenuHomeButtonMode(for position: HomeButtonPosition) -> String {
        switch position {
        case .hidden:
            return NSLocalizedString("main.menu.home.button.mode.hide", value: "Hide", comment: "Main Menu > View > Home Button > None item")
        case .left:
            return NSLocalizedString("main.menu.home.button.mode.left", value: "Show Left of the Back Button", comment: "Main Menu > View > Home Button > left position item")
        case .right:
            return NSLocalizedString("main.menu.home.button.mode.right", value: "Show Right of the Reload Button", comment: "Main Menu > View > Home Button > right position item")
        }
    }

    static let mainMenuViewShowAutofillShortcut = NSLocalizedString("Show Autofill Shortcut", comment: "Main Menu View item")
    static let mainMenuViewShowBookmarksShortcut = NSLocalizedString("Show Bookmarks Shortcut", comment: "Main Menu View item")
    static let mainMenuViewShowDownloadsShortcut = NSLocalizedString("Show Downloads Shortcut", comment: "Main Menu View item")
    static let mainMenuViewEnterFullScreen = NSLocalizedString("Enter Full Screen", comment: "Main Menu View item")
    static let mainMenuViewActualSize = NSLocalizedString("Actual Size", comment: "Main Menu View item")
    static let mainMenuViewZoomIn = NSLocalizedString("Zoom In", comment: "Main Menu View item")
    static let mainMenuViewZoomOut = NSLocalizedString("Zoom Out", comment: "Main Menu View item")
    static let mainMenuViewShowToolbarsOnFullScreen = NSLocalizedString("Show Tabs and Bookmarks Bar in Full Screen", comment: "Main Menu View item")

    static let mainMenuDeveloper = NSLocalizedString("Developer", comment: "Main Menu ")

    // MARK: Main Menu -> View -> Developer
    static let mainMenuViewDeveloperJavaScriptConsole = NSLocalizedString("JavaScript Console", comment: "Main Menu View-Developer item")
    static let mainMenuViewDeveloperShowPageSource = NSLocalizedString("Show Page Source", comment: "Main Menu View-Developer item")
    static let mainMenuViewDeveloperShowResources = NSLocalizedString("Show Resources", comment: "Main Menu View-Developer item")

    // MARK: - Main Menu -> History
    static let mainMenuHistory = NSLocalizedString("History", comment: "Main Menu ")
    static let mainMenuHistoryRecentlyClosed = NSLocalizedString("Recently Closed", comment: "Main Menu History item")
    static let mainMenuHistoryClearAllHistory = NSLocalizedString("Clear All History…", comment: "Main Menu History item")
    static let mainMenuHistoryManageBookmarks = NSLocalizedString("Manage Bookmarks", comment: "Main Menu History item")
    static let mainMenuHistoryFavoriteThisPage = NSLocalizedString("Favorite This Page…", comment: "Main Menu History item")
    static let mainMenuHistoryReopenAllWindowsFromLastSession = NSLocalizedString("Reopen All Windows from Last Session", comment: "Main Menu History item")

    // MARK: - Main Menu -> Bookmarks -> Bookmarks Bar
    static let mainMenuBookmarksShowBookmarksBarAlways = NSLocalizedString("Always Show", comment: "Preference for always showing the bookmarks bar")
    static let mainMenuBookmarksShowBookmarksBarNewTabOnly = NSLocalizedString("Only Show on New Tab", comment: "Preference for only showing the bookmarks bar on new tab")
    static let mainMenuBookmarksShowBookmarksBarNever = NSLocalizedString("Never Show", comment: "Preference for never showing the bookmarks bar on new tab")
    static let mainMenuBookmarksLeftAlignBookmarksBar = NSLocalizedString("Align Bookmarks to Left", comment: "Preference for left aligning the bookmarks bar")
    static let mainMenuBookmarksCenterAlignBookmarksBar = NSLocalizedString("Align Bookmarks to Center", comment: "Preference for center aligning the bookmarks bar")
    static let preferencesBookmarksCenterAlignBookmarksBarTitle = NSLocalizedString("Align Bookmarks", comment: "Preference title aligning the bookmarks bar")
    static let preferencesBookmarksCenterAlignBookmarksBar = NSLocalizedString("Center", comment: "Preference title aligning the bookmarks bar")
    static let preferencesBookmarksLeftAlignBookmarksBare = NSLocalizedString("Left", comment: "Preference title aligning the bookmarks bar")

    // MARK: - Main Menu -> Window
    static let mainMenuWindow = NSLocalizedString("Window", comment: "Main Menu ")
    static let mainMenuWindowMinimize = NSLocalizedString("Minimize", comment: "Main Menu Window item")
    static let mainMenuWindowMergeAllWindows = NSLocalizedString("Merge All Windows", comment: "Main Menu Window item")
    static let mainMenuWindowShowPreviousTab = NSLocalizedString("Show Previous Tab", comment: "Main Menu Window item")
    static let mainMenuWindowShowNextTab = NSLocalizedString("Show Next Tab", comment: "Main Menu Window item")
    static let mainMenuWindowBringAllToFront = NSLocalizedString("Bring All to Front", comment: "Main Menu Window item")

    // MARK: - Main Menu -> Help
    static let mainMenuHelp = NSLocalizedString("Help", comment: "Main Menu Help")
    static let mainMenuHelpDuckDuckGoHelp = NSLocalizedString("DuckDuckGo Help", comment: "Main Menu Help item")

    static let duplicateTab = NSLocalizedString("duplicate.tab", value: "Duplicate Tab", comment: "Menu item. Duplicate as a verb")
    static let pinTab = NSLocalizedString("pin.tab", value: "Pin Tab", comment: "Menu item. Pin as a verb")
    static let unpinTab = NSLocalizedString("unpin.tab", value: "Unpin Tab", comment: "Menu item. Unpin as a verb")
    static let closeTab = NSLocalizedString("close.tab", value: "Close Tab", comment: "Menu item")
    static let muteTab = NSLocalizedString("mute.tab", value: "Mute Tab", comment: "Menu item. Mute tab")
    static let unmuteTab = NSLocalizedString("unmute.tab", value: "Unmute Tab", comment: "Menu item. Unmute tab")
    static let closeOtherTabs = NSLocalizedString("close.other.tabs", value: "Close Other Tabs", comment: "Menu item")
    static let closeAllOtherTabs = NSLocalizedString("close.all.other.tabs", value: "Close All Other Tabs", comment: "Menu item")
    static let closeTabsToTheLeft = NSLocalizedString("close.tabs.to.the.left", value: "Close Tabs to the Left", comment: "Menu item")
    static let closeTabsToTheRight = NSLocalizedString("close.tabs.to.the.right", value: "Close Tabs to the Right", comment: "Menu item")
    static let openInNewTab = NSLocalizedString("open.in.new.tab", value: "Open in New Tab", comment: "Menu item that opens the link in a new tab")
    static let openInNewWindow = NSLocalizedString("open.in.new.window", value: "Open in New Window", comment: "Menu item that opens the link in a new window")
    static let openAllInNewTabs = NSLocalizedString("open.all.in.new.tabs", value: "Open All in New Tabs", comment: "Menu item that opens all the bookmarks in a folder to new tabs")
    static let openAllTabsInNewWindow = NSLocalizedString("open.all.tabs.in.new.window", value: "Open All in New Window", comment: "Menu item that opens all the bookmarks in a folder in a new window")
    static let showFolderContents = NSLocalizedString("show.folder.contents", value: "Show Folder Contents", comment: "Menu item that shows the content of a folder ")
    static let editBookmark = NSLocalizedString("menu.bookmarks.edit", value: "Edit…", comment: "Menu item to edit a bookmark or a folder")
    static let addFolder = NSLocalizedString("menu.add.folder", value: "Add Folder…", comment: "Menu item to add a folder")
    static let showInFolder = NSLocalizedString("menu.show.in.folder", value: "Show in Folder", comment: "Menu item to show where a bookmark is located")

    static let tabHomeTitle = NSLocalizedString("tab.home.title", value: "New Tab", comment: "Tab home title")
    static let tabUntitledTitle = NSLocalizedString("tab.empty.title", value: "Untitled", comment: "Title for an empty tab without a title")
    static let tabPreferencesTitle = NSLocalizedString("tab.preferences.title", value: "Settings", comment: "Tab preferences title")
    static let tabBookmarksTitle = NSLocalizedString("tab.bookmarks.title", value: "Bookmarks", comment: "Tab bookmarks title")
    static let tabOnboardingTitle = NSLocalizedString("tab.onboarding.title", value: "Welcome", comment: "Tab onboarding title")
    static let releaseNotesTitle = NSLocalizedString("tab.releaseNotes.title", value: "Release Notes", comment: "Title of deticated tab for Release Notes")

    // MARK: Error Pages
    static let tabErrorTitle = NSLocalizedString("tab.error.title", value: "Failed to open page", comment: "Tab error title")
    static let errorPageHeader = NSLocalizedString("page.error.header", value: "DuckDuckGo can’t load this page.", comment: "Error page heading text")
    static let webProcessCrashPageHeader = NSLocalizedString("page.crash.header", value: "This webpage has crashed.", comment: "Error page heading text shown when a Web Page process had crashed")
    static let webProcessCrashPageMessage = NSLocalizedString("page.crash.message", value: "Try reloading the page or come back later.", comment: "Error page message text shown when a Web Page process had crashed")
    static let sslErrorPageTabTitle = NSLocalizedString("ssl.error.page.tab.title", value: "Warning: Site May Be Insecure", comment: "Title shown in an error page tab that warn users of security risks on a website due to SSL issues")
    static let phishingErrorPageTabTitle = NSLocalizedString("phishing.error.page.tab.title", value: "Warning: Site May Be Deceptive", comment: "Title shown in an error page tab that warn users of security risks on a website that has been flagged as Phishing.")
    static let malwareErrorPageTabTitle = NSLocalizedString("malware.error.page.tab.title", value: "Warning: Site May Be Malicious", comment: "Title shown in an error page tab that warn users of security risks on a website that has been flagged as Malware.")

    static let openSystemPreferences = NSLocalizedString("open.preferences", value: "Open System Preferences", comment: "Open System Preferences (to re-enable permission for the App) (up to and including macOS 12")
    static let openSystemSettings = NSLocalizedString("open.settings", value: "Open System Settings…", comment: "This string represents a prompt or button label prompting the user to open system settings")
    static let checkForUpdate = NSLocalizedString("check.for.update", value: "Check for Update", comment: "Button users can use to check for a new update")

    static let unknownErrorTryAgainMessage = NSLocalizedString("error.unknown.try.again", value: "An unknown error has occurred", comment: "Generic error message on a dialog for when the cause is not known.")

    static let moveTabToNewWindow = NSLocalizedString("options.menu.move.tab.to.new.window",
                                                      value: "Move Tab to New Window",
                                                      comment: "Context menu item")

    static let searchDuckDuckGoSuffix = NSLocalizedString("address.bar.search.suffix",
                                                          value: "Search DuckDuckGo",
                                                          comment: "Suffix of searched terms in address bar. Example: best watching machine . Search DuckDuckGo")
    static let duckDuckGoSearchSuffix = NSLocalizedString("address.bar.search.open.tab.suffix",
                                                          value: "DuckDuckGo Search",
                                                          comment: "Suffix of DuckDuckGo Search open tab suggestion. Example: cats – DuckDuckGo Search")
    static let addressBarVisitSuffix = NSLocalizedString("address.bar.visit.suffix",
                                                         value: "Visit",
                                                         comment: "Address bar suffix of possibly visited website. Example: spreadprivacy.com . Visit spreadprivacy.com")
    static let addressBarPlaceholder = NSLocalizedString("address.bar.placeholder",
                                                         value: "Search or enter address",
                                                         comment: "Empty Address Bar placeholder text displayed on the new tab page.")

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
    static let openLinkInNewBurnerTab = NSLocalizedString("open.link.in.new.burner.tab", value: "Open Link in New Fire Tab", comment: "Context menu item")
    static let openImageInNewTab = NSLocalizedString("open.image.in.new.tab", value: "Open Image in New Tab", comment: "Context menu item")
    static let openImageInNewBurnerTab = NSLocalizedString("open.image.in.new.burner.tab", value: "Open Image in New Fire Tab", comment: "Context menu item")
    static let copyImageAddress = NSLocalizedString("copy.image.address", value: "Copy Image Address", comment: "Context menu item")
    static let saveImageAs = NSLocalizedString("save.image.as", value: "Save Image As…", comment: "Context menu item")
    static let copyEmailAddress = NSLocalizedString("copy.email.address", value: "Copy Email Address", comment: "Context menu item")
    static let copyEmailAddresses = NSLocalizedString("copy.email.addresses", value: "Copy Email Addresses", comment: "Context menu item")
    static let downloadLinkedFileAs = NSLocalizedString("download.linked.file.at", value: "Download Linked File As…", comment: "Context menu item")
    static let addLinkToBookmarks = NSLocalizedString("add.link.to.bookmarks", value: "Add Link to Bookmarks", comment: "Context menu item")
    static let bookmarkPage = NSLocalizedString("bookmark.page", value: "Bookmark Page", comment: "Context menu item")
    static let searchWithDuckDuckGo = NSLocalizedString("search.with.DuckDuckGo", value: "Search with DuckDuckGo", comment: "Context menu item")

    static let plusButtonNewTabMenuItem = NSLocalizedString("menu.item.new.tab", value: "New Tab", comment: "Context menu item")

    static let findInPage = NSLocalizedString("find.in.page", value: "%1$d of %2$d", comment: "Find in page status (e.g. 1 of 99)")

    static let moreMenuItem = NSLocalizedString("sharing.more", value: "More…", comment: "Sharing Menu -> More…")
    static let findInPageMenuItem = NSLocalizedString("find.in.page.menu.item", value: "Find in Page…", comment: "Menu item title")
    static let shareMenuItem = NSLocalizedString("share.menu.item", value: "Share", comment: "Menu item title")
    static let shareViaQRCodeMenuItem = NSLocalizedString("share.menu.item.qr.code", value: "Create QR Code", comment: "Menu item title")
    static let printMenuItem = NSLocalizedString("print.menu.item", value: "Print…", comment: "Menu item title")
    static let newWindowMenuItem = NSLocalizedString("new.window.menu.item", value: "New Window", comment: "Menu item title")
    static let newBurnerWindowMenuItem = NSLocalizedString("new.burner.window.menu.item", value: "New Fire Window", comment: "Menu item title")

    static let fireDialogFireproofSites = NSLocalizedString("fire.dialog.fireproof.sites", value: "Fireproof sites won't be cleared", comment: "Category of domains in fire button dialog")
    static let fireDialogClearSites = NSLocalizedString("fire.dialog.clear.sites", value: "Selected sites will be cleared", comment: "Category of domains in fire button dialog")
    static let fireDialogDelitingData = NSLocalizedString("fire.dialog.deliting.data", value: "Deleting browsing data…", comment: "Text shown in dialog while removing browsing data")
    static let fireInfoDialogTitle = NSLocalizedString("fire.info.dialog.title", value: "Leave No Trace", comment: "Title of the dialog that explains the Fire feature.")
    static let fireInfoDialogDescription = NSLocalizedString("fire.info.dialog.description", value: "Data, browsing history, and cookies can build up in your browser over time. Use the Fire Button to clear it all away.", comment: "Description in the dialog that explains the Fire feature.")
    static let fireDialogFireWindowTitle = NSLocalizedString("fire.dialog.fire-window.title", value: "Open New Fire Window", comment: "Title of the part of the dialog where the user can open a fire window.")
    static let fireDialogFireWindowDescription = NSLocalizedString("fire.dialog.fire-window.description", value: "An isolated window that doesn’t save any data", comment: "Explanation of what a fire window is.")
    static let fireDialogCloseTabs = NSLocalizedString("fire.dialog.fire-window.close-tabs", value: "Close Tabs and Clear Data", comment: "Title of the dialog where the user can close browser tabs and clear data.")
    static let fireDialogBurnWindowButton = NSLocalizedString("fire.dialog.close-burner-window", value: "Close and Burn This Window", comment: "Button that allows the user to close and burn the browser burner window")
    static let allData = NSLocalizedString("fire.all-sites", value: "All sites", comment: "Configuration option for fire button")
    static let currentTab = NSLocalizedString("fire.currentTab", value: "All sites visited in current tab", comment: "Configuration option for fire button")
    static let currentWindow = NSLocalizedString("fire.currentWindow", value: "All sites visited in current window", comment: "Configuration option for fire button")
    static let allDataDescription = NSLocalizedString("fire.all-data.description", value: "Clear all tabs and related site data", comment: "Description of the 'All Data' configuration option for the fire button")
    static let currentWindowDescription = NSLocalizedString("fire.current-window.description", value: "Clear current window and related site data", comment: "Description of the 'Current Window' configuration option for the fire button")
    static let selectSiteToClear = NSLocalizedString("fire.select-site-to-clear", value: "Select a site to clear its data.", comment: "Info label in the fire button popover")
    static func activeTabsInfo(tabs: Int, sites: Int) -> String {
        let localized = NSLocalizedString("fire.active-tabs-info",
                                          value: "Close active tabs (%d) and clear all browsing history and cookies (sites: %d).",
                                          comment: "Info in the Fire Button popover")
        return String(format: localized, tabs, sites)
    }
    static func oneTabInfo(sites: Int) -> String {
        let localized = NSLocalizedString("fire.one-tab-info",
                                          value: "Close this tab and clear its browsing history and cookies (sites: %d).",
                                          comment: "Info in the Fire Button popover")
        return String(format: localized, sites)
    }
    static let fireDialogDetails = NSLocalizedString("fire.dialog.details", value: "Details", comment: "Button to show more details")
    static let fireDialogWindowWillClose = NSLocalizedString("fire.dialog.window-will-close", value: "Current window will close", comment: "Warning label shown in an expanded view of the fire popover")
    static let fireDialogTabWillClose = NSLocalizedString("fire.dialog.tab-will-close", value: "Current tab will close", comment: "Warning label shown in an expanded view of the fire popover")
    static let fireDialogPinnedTabWillReload = NSLocalizedString("fire.dialog.tab-will-reload", value: "Pinned tab will reload", comment: "Warning label shown in an expanded view of the fire popover")
    static let fireDialogAllWindowsWillClose = NSLocalizedString("fire.dialog.all-windows-will-close", value: "All windows will close", comment: "Warning label shown in an expanded view of the fire popover")
    static let fireproofSite = NSLocalizedString("options.menu.fireproof-site", value: "Fireproof This Site", comment: "Context menu item")
    static let removeFireproofing = NSLocalizedString("options.menu.remove-fireproofing", value: "Remove Fireproofing", comment: "Context menu item")
    static let fireproof = NSLocalizedString("fireproof", value: "Fireproof", comment: "Fireproof button")

    static func domainIsFireproof(domain: String) -> String {
        let localized = NSLocalizedString("domain-is-fireproof", value: "%@ is now Fireproof", comment: "Domain fireproof status")
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
    static let webTrackingProtectionSettingsTitle = NSLocalizedString("web.tracking.protection.title", value: "Web Tracking Protection", comment: "Web tracking protection settings section title")
    static let webTrackingProtectionExplenation = NSLocalizedString("web.tracking.protection.explenation", value: "DuckDuckGo automatically blocks hidden trackers as you browse the web.", comment: "Privacy feature explanation in the browser settings")
    static let autoconsentCheckboxTitle = NSLocalizedString("autoconsent.checkbox.title", value: "Automatically handle cookie pop-ups", comment: "Autoconsent settings checkbox title")
    static let autoconsentExplanation = NSLocalizedString("autoconsent.explanation", value: "DuckDuckGo will try to select the most private settings available and hide these pop-ups for you.", comment: "Autoconsent feature explanation in settings")
    static let privateSearchExplanation = NSLocalizedString("private.search.explenation", value: "DuckDuckGo Private Search is your default search engine, so you can search the web without being tracked.", comment: "feature explanation in settings")
    static let webTrackingProtectionExplanation = NSLocalizedString("web.tracking.protection.explanation", value: "DuckDuckGo automatically blocks hidden trackers as you browse the web.", comment: "feature explanation in settings")
    static let emailProtectionExplanation = NSLocalizedString("email.protection.explanation", value: "Block email trackers and hide your address without switching your email provider.", comment: "Email protection feature explanation in settings. The feature blocks email trackers and hides original email address.")

    // Misc

    // AI Chat
    static let aiChatOnboardingPopoverTitle = NSLocalizedString("duckai.onboarding.popover.title", value: "Launch Duck.ai directly from your toolbar", comment: "AI Chat onboarding popover title")
    static let aiChatOnboardingPopoverMessageMarkdown = NSLocalizedString("duck.ai.onboarding.popover.message-markdown", value: "You can adjust this and other Duck.ai features in **Settings** > **Duck.ai**.", comment: "AI Chat onboarding popover message, make sure to keep Settings and AI Chat inside ** **")
    static let aiChatOnboardingPopoverMessageFallback = NSLocalizedString("ai-chat.onboarding.popover.message-fallback", value: "You can adjust this and other AI Chat features in Settings > AI Chat", comment: "AI Chat onboarding popover message continuation")
    static let aiChatOnboardingPopoverCTAReject = NSLocalizedString("ai-chat.onboarding.popover.reject", value: "No Thanks", comment: "AI Chat onboarding CTA for rejection")
    static let aiChatOnboardingPopoverCTAAccept = NSLocalizedString("ai-chat.onboarding.popover.accept", value: "Add Shortcut", comment: "AI Chat onboarding CTA for approval")
    static let aiChatOnboardingPopoverConfirmation = NSLocalizedString("duckai.onboarding.popover.confirmation", value: "Duck.ai shortcut added!", comment: "Confirmation for accepting the AI Chat onboarding popover")

    static let aiChatShowInToolbarToggle = NSLocalizedString("duckai.show-in-toolbar.toggle", value: "Show Duck.ai shortcut in browser toolbar", comment: "Show AI Chat in toolbar")

    static let aiChatShowInApplicationMenuToggle = NSLocalizedString("duckai.show-in-application-menu.toggle-setting", value: "Show “New AI Chat” in File and application menus", comment: "Show Duck.ai in application menus")

    static let aiChatPreferencesCaption = NSLocalizedString("duckai.preferences.caption", value: "Duck.ai is an optional feature that lets you chat anonymously with popular 3rd-party AI chat models. Your chats are not used to train AI.", comment: "Ai Chat preferences explanation")

    static let aiChatPreferencesLearnMoreButton = NSLocalizedString("ai-chat.preferences.learn-more", value: "Learn More", comment: "AI Chat preferences button to learn more about it")

    static let newAIChatMenuItem = NSLocalizedString("duckai.menu.new", value: "New AI Chat", comment: "Menu item to launch AI Chat")

    // Duck Player Preferences
    static let duckPlayerSettingsTitle = NSLocalizedString("duck-player.title", value: "Duck Player", comment: "Private YouTube Player settings title")
    static let duckPlayerAlwaysOpenInPlayer = NSLocalizedString("duck-player.always-open-in-player", value: "Always open YouTube videos in Duck Player", comment: "Private YouTube Player option")
    static let duckPlayerShowPlayerButtons = NSLocalizedString("duck-player.show-buttons", value: "Show option to use Duck Player over YouTube previews on hover", comment: "Private YouTube Player option")
    static let duckPlayerOff = NSLocalizedString("duck-player.off", value: "Never use Duck Player", comment: "Private YouTube Player option")
    static let duckPlayerExplanation = NSLocalizedString("duck-player.explanation", value: "Duck Player provides a clean viewing experience without personalized ads and prevents viewing activity from influencing your YouTube recommendations.", comment: "Private YouTube Player explanation in settings")
    static let duckPlayerAutoplayPreference = NSLocalizedString("duck-player.video-autoplay-preference", value: "Autoplay videos when opened in Duck Player", comment: "Autoplay preference in settings")
    static let duckPlayerNewTabPreference = NSLocalizedString("duck-player.newtab-preference", value: "Open Duck Player in a new tab whenever possible", comment: "New tab preference in settings")
    static let duckPlayerNewTabPreferenceExtraInfo = NSLocalizedString("duck-player.newtab.info-preference", value: "When browsing YouTube on the web", comment: "New tab preference extra info in settings")
    static let duckPlayerVideoPreferencesTitle = NSLocalizedString("duck-player.video-preferences-title", value: "Video Preferences", comment: "Video Preferences title in settings")

    static let duckPlayerContingencyMessageTitle = NSLocalizedString("duck-player.contingency-title", value: "Duck Player Unavailable", comment: "Title for message explaining to the user that Duck Player is not available")
    static let duckPlayerContingencyMessageBody = NSLocalizedString("duck-player.video-contingency-message", value: "Duck Player's functionality has been affected by recent changes to YouTube. We’re working to fix these issues and appreciate your understanding.", comment: "Message explaining to the user that Duck Player is not available")
    static let duckPlayerContingencyMessageCTA = NSLocalizedString("duck-player.video-contingency-cta", value: "Learn More", comment: "Button for the message explaining to the user that Duck Player is not available so the user can learn more")

    static let duckPlayerOnboardingChoiceModalTitleTop = NSLocalizedString("duck-player.onboarding-choice-modal-title-top", value: "Drowning in ads on YouTube?", comment: "Top title for a Duck Player onboarding modal screen")
    static let duckPlayerOnboardingChoiceModalTitleBottom = NSLocalizedString("duck-player.onboarding-choice-modal-title-bottom", value: "Try Duck Player!", comment: "Bottom title for a Duck Player onboarding modal screen")

    static let duckPlayerOnboardingChoiceModalMessage = NSLocalizedString("duck-player.onboarding-choice-modal-message-body", value: "Duck Player lets you watch YouTube without targeted ads in DuckDuckGo and what you watch won't influence your recommendations.", comment: "Message for a Duck Player onboarding modal screen")
    static let duckPlayerOnboardingChoiceModalCTAConfirm = NSLocalizedString("duck-player.onboarding-choice-modal-CTA-confirm", value: "Turn on Duck Player", comment: "Confirm Button to enable Duck Player. -Duck Player- should not be translated")
    static let duckPlayerOnboardingChoiceModalCTADeny = NSLocalizedString("duck-player.onboarding-choice-modal-CTA-deny", value: "Not Now", comment: "Deny Button to enable Duck Player")

    static let duckPlayerOnboardingConfirmationModalTitle = NSLocalizedString("duck-player.onboarding-confirmation-modal-title", value: "All set!", comment: "Title for a Duck Player onboarding modal confirmation screen")
    static let duckPlayerOnboardingConfirmationModalMessage = NSLocalizedString("duck-player.onboarding-confirmation-modal-message", value: "Pick a video to see Duck Player work its magic.", comment: "Message for a Duck Player onboarding modal confirmation screen")
    static let duckPlayerOnboardingConfirmationModalCTAConfirm = NSLocalizedString("duck-player.onboarding-confirmation-modal-CTA-confirm", value: "Got it", comment: "Button to confirm on Duck Player onboarding modal confirmation screen")


    static let gpcCheckboxTitle = NSLocalizedString("gpc.checkbox.title", value: "Enable Global Privacy Control", comment: "GPC settings checkbox title")
    static let gpcExplanation = NSLocalizedString("gpc.explanation", value: "Tells participating websites not to sell or share your data.", comment: "GPC explanation in settings")
    static let learnMore = NSLocalizedString("learnmore.link", value: "Learn More", comment: "Learn More link")

    static let autofillOnboardingPopoverCTAReject = NSLocalizedString("autofill.onboarding.popover.reject", value: "No Thanks", comment: "Autofill onboarding CTA for rejection")
    static let autofillOnboardingPopoverCTAAccept = NSLocalizedString("autofill.onboarding.popover.accept", value: "Add Shortcut", comment: "Autofill onboarding CTA for approval")
    static let autofillOnboardingPopoverTitle = NSLocalizedString("autofill.onboarding.popover.title", value: "Add passwords shortcut?", comment: "Autofill onboarding popover title")
    static let autofillOnboardingPopoverMessage = NSLocalizedString("autofill.onboarding.popover.message1", value: "You can manage your toolbar shortcuts at any time by right-clicking on the toolbar.", comment: "Autofill onboarding popover message")

    static let autofillPasswordManager = NSLocalizedString("autofill.password-manager", value: "Password Manager", comment: "Autofill settings section title")
    static let autofillPasswordManagerDuckDuckGo = NSLocalizedString("autofill.password-manager.duckduckgo", value: "DuckDuckGo built-in password manager", comment: "Autofill password manager row title")
    static let autofillPasswordManagerBitwarden = NSLocalizedString("autofill.password-manager.bitwarden", value: "Bitwarden", comment: "Autofill password manager row title")
    static let autofillPasswordManagerBitwardenDisclaimer = NSLocalizedString("autofill.password-manager.bitwarden.disclaimer", value: "Setup requires installing the Bitwarden app.", comment: "Autofill password manager Bitwarden disclaimer")
    static let restartBitwarden = NSLocalizedString("restart.bitwarden", value: "Restart Bitwarden", comment: "Button to restart Bitwarden application")
    static let restartBitwardenInfo = NSLocalizedString("restart.bitwarden.info", value: "Bitwarden is not responding. Please restart it to initiate the communication again", comment: "This string represents a message informing the user that Bitwarden is not responding and prompts them to restart the application to initiate communication again.")

    static let autofillViewContentButtonPasswords = NSLocalizedString("autofill.view-autofill-content.passwords", value: "Open Passwords…", comment: "View Password Content Button title in the autofill Settings")
    static let autofillViewContentButtonPaymentMethods = NSLocalizedString("autofill.view-autofill-content.payment-methods", value: "Open Payment Methods…", comment: "View Payment Methods Content Button title in the autofill Settings")
    static let autofillViewContentButtonIdentities = NSLocalizedString("autofill.view-autofill-content.identities", value: "Open Identities…", comment: "View Identities Content Button title in the autofill Settings")
    static let autofillAskToSave = NSLocalizedString("autofill.ask-to-save", value: "Ask to Save and Autofill", comment: "Autofill settings section title")
    static let autofillAskToSaveExplanation = NSLocalizedString("autofill.ask-to-save.explanation", value: "Receive prompts to save new information and autofill online forms.", comment: "Description of Autofill autosaving feature - used in settings")
    static let autofillPasswords = NSLocalizedString("autofill.passwords", value: "Passwords", comment: "Autofill autosaved data type")
    static let autofillAddresses = NSLocalizedString("autofill.addresses", value: "Addresses", comment: "Autofill autosaved data type")
    static let autofillPaymentMethods = NSLocalizedString("autofill.payment-methods", value: "Payment methods", comment: "Autofill autosaved data type")
    static let autofillExcludedSites = NSLocalizedString("autofill.excluded-sites", value: "Excluded Sites", comment: "Autofill settings section title")
    static let autofillExcludedSitesExplanation = NSLocalizedString("autofill.excluded-sites.explanation", value: "Websites you selected to never ask to save your password.", comment: "Subtitle providing additional information about the excluded sites section")
    static let autofillExcludedSitesReset = NSLocalizedString("autofill.excluded-sites.reset", value: "Reset", comment: "Button title allowing users to reset their list of excluded sites")
    static let autofillExcludedSitesResetActionTitle = NSLocalizedString("autofill.excluded-sites.reset.action.title", value: "Reset Excluded Sites?", comment: "Alert title")
    static let autofillExcludedSitesResetActionMessage = NSLocalizedString("autofill.excluded-sites.reset.action.message", value: "If you reset excluded sites, you will be prompted to save your password next time you sign in to any of these sites.", comment: "Alert title")
    static let autofillAutoLock = NSLocalizedString("autofill.auto-lock", value: "Auto-lock", comment: "Autofill settings section title")
    static let autofillLockWhenIdle = NSLocalizedString("autofill.lock-when-idle", value: "Lock autofill after computer is idle for", comment: "Autofill auto-lock setting")
    static let autofillNeverLock = NSLocalizedString("autofill.never-lock", value: "Never lock autofill", comment: "Autofill auto-lock setting")
    static let autofillNeverLockWarning = NSLocalizedString("autofill.never-lock-warning", value: "If not locked, anyone with access to your device will be able to use and modify your autofill data. For security purposes, credit card form fill always requires authentication.", comment: "Autofill disabled auto-lock warning")
    static let autolockLocksFormFill = NSLocalizedString("autofill.autolock-locks-form-filling", value: "Also lock password form fill", comment: "Lock form filling when auto-lock is active text")

    static let downloadsLocation = NSLocalizedString("downloads.location", value: "Location", comment: "Downloads directory location")
    static let downloadsAlwaysAsk = NSLocalizedString("downloads.always-ask", value: "Always ask where to save files", comment: "Downloads preferences checkbox")
    static let downloadsChangeDirectory = NSLocalizedString("downloads.change", value: "Change…", comment: "Change downloads directory button")

    static let downloadsOpenPopupOnCompletion = NSLocalizedString("downloads.open.on.completion", value: "Automatically open the Downloads panel when downloads complete", comment: "Checkbox to open a Download Manager popover when downloads are completed")

    static let maliciousSiteDetectionHeader = NSLocalizedString("phishing-detection.enabled.header", value: "Site Safety Warnings", comment: "Header for phishing site protection section in the settings page")
    static let maliciousSiteDetectionIsEnabled = NSLocalizedString("phishing-detection.enabled.checkbox", value: "Warn me on sites flagged for phishing or malware.", comment: "Checkbox that enables or disables the phishing and malware detection feature in the browser")
    static let maliciousDetectionEnabledWarning = NSLocalizedString("phishing-detection.enabled.warning", value: "Disabling this feature can put your personal information at risk.", comment: "A description box to warn users away from disabling the phishing and malware protection feature")

    // MARK: Password Manager
    static let passwordManagementAllItems = NSLocalizedString("passsword.management.all-items", value: "All Items", comment: "Used as title for the Autofill All Items option")
    static let passwordManagementLogins = NSLocalizedString("passsword.management.logins", value: "Passwords", comment: "Used as title for the Autofill Logins option")
    static let passwordManagementIdentities = NSLocalizedString("passsword.management.identities", value: "Identities", comment: "Used as title for the Autofill Identities option")
    static let passwordManagementCreditCards = NSLocalizedString("passsword.management.credit-cards", value: "Credit Cards", comment: "Used as title for the Autofill Credit Cards option")
    static let passwordManagementCreditCardsUnknownCard = NSLocalizedString("autofill.management.credit-cards.unknown.card", value: "Card", comment: "Used as placeholder when user iserts a credit card of unknown type (e.g. not Visa, Mastercard)")
    static let passwordManagementNotes = NSLocalizedString("passsword.management.notes", value: "Notes", comment: "Used as title for the Autofill Notes option")
    static let passwordManagementLock = NSLocalizedString("passsword.management.lock", value: "Lock", comment: "Lock Logins Vault menu")
    static let passwordManagementUnlock = NSLocalizedString("passsword.management.unlock", value: "Unlock", comment: "Unlock Logins Vault menu")
    static let passwordManagementSavePayment = NSLocalizedString("passsword.management.save.payment", value: "Save Payment Method?", comment: "Title of dialog that allows the user to save a payment method")
    static let passwordManagementSaveAddress = NSLocalizedString("passsword.management.save.address", value: "Save Address?", comment: "Title of dialog that allows the user to save an address method")
    static let passwordManagementSaveCredentialsPasswordManagerTitle = NSLocalizedString("passsword.management.save.credentials.password.manager.title", value: "Save password to Bitwarden?", comment: "Title of the passwored manager section of dialog that allows the user to save credentials")
    static let passwordManagementSaveCredentialsUnlockPasswordManager = NSLocalizedString("passsword.management.save.credentials.unlock.password.manager", value: "Unlock Bitwarden to Save", comment: "In the password manager dialog, alerts the user that they need to unlock Bitworden before being able to save the credential")
    static let passwordManagementSaveCredentialsFireproofCheckboxTitle = NSLocalizedString("passsword.management.save.credentials.fireproof.checkbox.title", value: "Fireproof this website", comment: "In the password manager dialog, title of the section that allows the user to fireproof a website via a checkbox")
    static let passwordManagementSaveCredentialsFireproofCheckboxDescription = NSLocalizedString("passsword.management.save.credentials.fireproof.checkbox.description", value: "Keeps you signed in after using the Fire Button", comment: "In the password manager dialog, description of the section that allows the user to fireproof a website via a checkbox")
    static func passwordManagementSaveCredentialsAccountLabel(activeVault: String) -> String {
        let localized = NSLocalizedString("passsword.management.save.credentials.account.label", value: "Connected to %@", comment: "In the password manager dialog, label that specifies the password manager vault we are connected with")
        return String(format: localized, activeVault)
    }
    static let passwordManagementTitle = NSLocalizedString("password.management.title", value: "Passwords & Autofill", comment: "Used as the title for menu item and related Settings page")
    static let settingsSuspended = NSLocalizedString("Settings…", comment: "Menu item")
    static let passwordManagerUnlockAutofill = NSLocalizedString("passsword.manager.unlock.autofill", value: "Unlock your Autofill info", comment: "In the password manager text of button to unlock autofill info")
    static let passwordManagerEmptyStateTitle = NSLocalizedString("passsword.manager.empty.state.title", value: "No logins or credit card info yet", comment: "In the password manager title when there are no items")
    static let passwordManagerEmptyStateMessage = NSLocalizedString("passsword.manager.empty.state.message", value: "If your logins are saved in another browser, you can import them into DuckDuckGo.", comment: "In the password manager message when there are no items")
    static let passwordManagerAlertRemovePasswordConfirmation = NSLocalizedString("passsword.manager.alert.remove-password.confirmation", value: "Are you sure you want to delete this saved password", comment: "Text of the alert that asks the user to confirm they want to delete a password")
    static let passwordManagerAlertSaveChanges = NSLocalizedString("passsword.manager.alert.save-changes", value: "Save the changes you made?", comment: "Text of the alert that asks the user if the want to save the changes made")
    static let passwordManagerAlertDuplicatePassword = NSLocalizedString("passsword.manager.alert.duplicate.password", value: "Duplicate Password", comment: "Title of the alert that the password inserted already exists")
    static let passwordManagerAlertDuplicatePasswordDescription = NSLocalizedString("passsword.manager.alert.duplicate.password.description", value: "You already have a password saved for this username and website.", comment: "Text of the alert that explains the password inserted already exists for a given website")
    static let thisActionCannotBeUndone = NSLocalizedString("action-cannot-be-undone", value: "This action cannot be undone.", comment: "Text used in alerts to warn user that a given action cannot be undone")
    static let passwordManagerAlertDeleteButton = NSLocalizedString("passsword.manager.alert.delete", value: "Delete", comment: "Button of the alert that asks the user to confirm they want to delete an password, login or credential to actually delete")
    static let passwordManagerAlertRemoveCardConfirmation = NSLocalizedString("passsword.manager.alert.remove-card.confirmation", value: "Are you sure you want to delete this saved credit card?", comment: "Text of the alert that asks the user to confirm they want to delete a credit card")
    static let passwordManagerAlertRemoveIdentityConfirmation = NSLocalizedString("passsword.manager.alert.remove-identity.confirmation", value: "Are you sure you want to delete this saved autofill info?", comment: "Text of the alert that asks the user to confirm they want to delete an identity")
    static let passwordManagerAlertRemoveNoteConfirmation = NSLocalizedString("passsword.manager.alert.remove-note.confirmation", value: "Are you sure you want to delete this note?", comment: "Text of the alert that asks the user to confirm they want to delete a note")

    static let importBookmarks = NSLocalizedString("import.browser.data.bookmarks", value: "Import Bookmarks…", comment: "Opens Import Browser Data dialog")
    static let importPasswords = NSLocalizedString("import.browser.data.passwords", value: "Import Passwords…", comment: "Opens Import Browser Data dialog")

    static let importDataTitle = NSLocalizedString("import.browser.data", value: "Import to DuckDuckGo", comment: "Import Browser Data dialog title")
    static let importDataTitleOnboarding = NSLocalizedString("import.browser.data.onboarding", value: "Great, let’s keep this simple!", comment: "Import Browser Data dialog title")
    static let importDataShortcutsTitle = NSLocalizedString("import.browser.data.shortcuts", value: "Almost done!", comment: "Import Browser Data dialog title for final stage when choosing shortcuts to enable")
    static let importDataShortcutsSubtitle = NSLocalizedString("import.browser.data.shortcuts.subtitle", value: "You can always right-click on the browser toolbar to find more shortcuts like these.", comment: "Subtitle explaining how users can find toolbar shortcuts.")
    static let importDataSourceTitle = NSLocalizedString("import.browser.data.source.title", value: "Where do you want to import from?", comment: "Import Browser Data title for option to choose source browser to import from")
    static let importDataSubtitle = NSLocalizedString("import.browser.data.source.subtitle", value: "Access and manage your passwords in DuckDuckGo Settings > Passwords & Autofill.", comment: "Subtitle explaining where users can find imported passwords.")
    static let importDataSuccessTitle = NSLocalizedString("import.browser.data.success.title", value: "Import complete!", comment: "message about Passwords and or bookmarks Data Import completion")

    static let exportLogins = NSLocalizedString("export.logins.data", value: "Export Passwords…", comment: "Opens Export Logins Data dialog")
    static let exportBookmarks = NSLocalizedString("export.bookmarks.menu.item", value: "Export Bookmarks…", comment: "Export bookmarks menu item")
    static let bookmarks = NSLocalizedString("bookmarks", value: "Bookmarks", comment: "Button for bookmarks")
    static let favorites = NSLocalizedString("favorites", value: "Favorites", comment: "Title text for the Favorites menu item")
    static let newBookmark = NSLocalizedString("bookmarks.add.dialog.title", value: "New Bookmark", comment: "Bookmark creation dialog title")
    static let bookmarksOpenInNewTabs = NSLocalizedString("bookmarks.open.in.new.tabs", value: "Open in New Tabs", comment: "Open all bookmarks in folder in new tabs")
    static let addToFavorites = NSLocalizedString("add.to.favorites", value: "Add to Favorites", comment: "Button for adding bookmarks to favorites")
    static let addFavorite = NSLocalizedString("add.favorite", value: "Add Favorite", comment: "Button for adding a favorite bookmark")
    static let editFavorite = NSLocalizedString("edit.favorite", value: "Edit Favorite", comment: "Header of the view that edits a favorite bookmark")
    static let removeFromFavorites = NSLocalizedString("remove.from.favorites", value: "Remove from Favorites", comment: "Button for removing bookmarks from favorites")
    static let bookmarkThisPage = NSLocalizedString("bookmark.this.page", value: "Bookmark This Page…", comment: "Menu item for bookmarking current page")
    static let bookmarkAllTabs = NSLocalizedString("bookmark.all.tabs", value: "Bookmark All Tabs…", comment: "Menu item for bookmarking all the open tabs")
    static let bookmarksShowToolbarPanel = NSLocalizedString("bookmarks.show-toolbar-panel", value: "Open Bookmarks Panel", comment: "Menu item for opening the bookmarks panel")
    static let bookmarksManageBookmarks = NSLocalizedString("bookmarks.manage-bookmarks", value: "Manage Bookmarks", comment: "Menu item for opening the bookmarks management interface")
    static let bookmarkImportedFromFolder = NSLocalizedString("bookmarks.imported.from.folder", value: "Imported from", comment: "Name of the folder the imported bookmarks are saved into")

    // MARK: Feedback
    static let sendPProFeedback = NSLocalizedString("send.ppro.feedback", value: "Send Privacy Pro Feedback", comment: "Menu with feedback commands")
    static let reportBrokenSite = NSLocalizedString("report.broken.site", value: "Report Broken Site", comment: "Menu with feedback commands")
    static let browserFeedback = NSLocalizedString("send.browser.feedback", value: "Send Browser Feedback", comment: "Menu with feedback commands")
    static let browserFeedbackTitle = NSLocalizedString("send.browser.feedback.title", value: "Help Improve the DuckDuckGo Browser", comment: "Title of the interface to send feedback on the browser")
    static let browserFeedbackReportProblem = NSLocalizedString("send.browser.feedback.report-problem", value: "Report a problem", comment: "Name of the option the user can chose to give browser feedback about a problem they enountered")
    static let browserFeedbackRequestFeature = NSLocalizedString("send.browser.feedback.request-feature", value: "Request a feature", comment: "Name of the option the user can chose to give browser feedback about a feature they would like")
    static let browserFeedbackGeneralFeedback = NSLocalizedString("send.browser.feedback.general-feedback", value: "General feedback", comment: "Name of the option the user can chose to give general browser feedback")
    static let browserFeedbackSelectCategory = NSLocalizedString("send.browser.feedback.select-category", value: "Select a category", comment: "Title of the picker where the user can chose the category of the feedback they want ot send.")
    static let browserFeedbackThankYou = NSLocalizedString("send.browser.feedback.thankyou", value: "Thank you!", comment: "Thanks the user for sending feedback")
    static let browserFeedbackFeedbackHelps = NSLocalizedString("send.browser.feedback.feedback-helps", value: "Your feedback will help us improve the DuckDuckGo browser.", comment: "Text shown to the user when they provide feedback.")

    static let otherBookmarksImportedFolderTitle = NSLocalizedString("bookmarks.imported.other.folder.title", value: "Other bookmarks", comment: "Name of the \"Other bookmarks\" folder imported from other browser")
    static let mobileBookmarksImportedFolderTitle = NSLocalizedString("bookmarks.imported.mobile.folder.title", value: "Mobile bookmarks", comment: "Name of the \"Mobile bookmarks\" folder imported from other browser")

    static let zoom = NSLocalizedString("zoom", value: "Zoom", comment: "Menu with Zooming commands")
    static let resetZoom = NSLocalizedString("reset-zoom", value: "Reset", comment: "Button that allows the user to reset the zoom level of the browser page")

    static let emailOptionsMenuItem = NSLocalizedString("email.optionsMenu", value: "Email Protection", comment: "Menu item email feature")
    static let emailOptionsMenuCreateAddressSubItem = NSLocalizedString("email.optionsMenu.createAddress", value: "Generate Private Duck Address", comment: "Create an email alias sub menu item")
    static let emailOptionsMenuTurnOffSubItem = NSLocalizedString("email.optionsMenu.turnOff", value: "Disable Email Protection Autofill", comment: "Disable email sub menu item")
    static let emailOptionsMenuTurnOnSubItem = NSLocalizedString("email.optionsMenu.turnOn", value: "Enable Email Protection", comment: "Sub menu item to enable Email Protection")
    static let privateEmailCopiedToClipboard = NSLocalizedString("email.copied", value: "New address copied to your clipboard", comment: "Notification that the Private email address was copied to clipboard after the user generated a new address")
    static let emailOptionsMenuManageAccountSubItem = NSLocalizedString("email.optionsMenu.manageAccount", value: "Manage Account", comment: "Manage private email account sub menu item")

    static let newFolder = NSLocalizedString("folder.optionsMenu.newFolder", value: "New Folder", comment: "Option for creating a new folder")
    static let renameFolder = NSLocalizedString("folder.optionsMenu.renameFolder", value: "Rename Folder", comment: "Option for renaming a folder")
    static let deleteFolder = NSLocalizedString("folder.optionsMenu.deleteFolder", value: "Delete Folder", comment: "Option for deleting a folder")
    static let newBookmarkDialogBookmarkNameTitle = NSLocalizedString("add.bookmark.name", value: "Name:", comment: "New bookmark folder dialog folder name field heading")

    static let updateBookmark = NSLocalizedString("bookmark.update", value: "Update Bookmark", comment: "Option for updating a bookmark")

    static let failedToOpenExternally = NSLocalizedString("open.externally.failed", value: "The app required to open that link can’t be found", comment: "’Link’ is link on a website, it couldn't be opened due to the required app not being found")

    // MARK: Permission
    static let locationPermissionAuthorizationFormat = NSLocalizedString("permission.authorization.location",
                                                                         value: "“%@“ website would like to use your current location.",
                                                                         comment: "Popover asking for domain %@ to use location")
    static let devicePermissionAuthorizationFormat = NSLocalizedString("permission.authorization.format",
                                                                       value: "Allow “%@“ to use your %@?",
                                                                       comment: "Popover asking for domain %@ to use camera/mic (%@)")
    static let popupWindowsPermissionAuthorizationFormat = NSLocalizedString("permission.authorization.popups.format",
                                                                             value: "Allow “%@“ to open PopUp Window?",
                                                                             comment: "Popover asking for domain %@ to open Popup Window")
    static let permissionMenuHeaderPopupWindowsFormat = NSLocalizedString("permission.authorization.popups.menu-header",
                                                                          value: "Allow “%@“ to open PopUp Windows?",
                                                                          comment: "Popover asking for domain %@ to open Popup Window")
    static let externalSchemePermissionAuthorizationFormat = NSLocalizedString("permission.authorization.externalScheme.format",
                                                                               value: "“%@” would like to open this link in %@",
                                                                               comment: "Popover asking for domain %@ to open link in External App (%@)")
    static let externalSchemePermissionAuthorizationNoDomainFormat = NSLocalizedString("permission.authorization.externalScheme.empty.format",
                                                                                       value: "Open this link in %@?",
                                                                                       comment: "Popover asking to open link in External App (%@)")
    static let permissionAlwaysAllowOnDomainCheckbox = NSLocalizedString("dashboard.permission.allow.on", value: "Always allow on", comment: "Permission Popover 'Always allow on' (for domainName) checkbox")

    static let permissionMicrophone = NSLocalizedString("permission.microphone", value: "Microphone", comment: "Microphone input media device name")
    static let permissionCamera = NSLocalizedString("permission.camera", value: "Camera", comment: "Camera input media device name")
    static let permissionCameraAndMicrophone = NSLocalizedString("permission.cameraAndmicrophone", value: "Camera and Microphone", comment: "camera and microphone input media devices name")
    static let permissionGeolocation = NSLocalizedString("permission.geolocation", value: "Location", comment: "User's Geolocation permission access name")
    static let permissionPopups = NSLocalizedString("permission.popups", value: "Pop-ups", comment: "Open Pop Up Windows permission access name")

    static let permissionMuteFormat = NSLocalizedString("permission.mute", value: "Pause %@ use on “%@”", comment: "Temporarily pause input media device %@ access for %@2 website")
    static let permissionUnmuteFormat = NSLocalizedString("permission.unmute", value: "Resume %@ use on “%@”", comment: "Resume input media device %@ access for %@ website")
    static let permissionReloadToEnable = NSLocalizedString("permission.reloadPage", value: "Reload to ask permission again", comment: "Reload webpage to ask for input media device access permission again")

    static let permissionAllowExternalSchemeFormat = NSLocalizedString("permission.allow.externalScheme.format", value: "Allow “%@“ to open %@", comment: "Allow to open External Link (%@ 2) to open on current domain (%@ 1)")
    static let permissionMenuHeaderExternalSchemeFormat = NSLocalizedString("permission.allow.externalScheme.menu-header", value: "Allow the %@ to open “%@” links", comment: "Allow the App Name(%@ 1) to open “URL Scheme”(%@ 2) links")

    static let permissionAppPermissionDisabledFormat = NSLocalizedString("permission.disabled.app", value: "%@ access is disabled for %@", comment: "The app (DuckDuckGo: %@ 2) has no access permission to (%@ 1) media device")
    static let permissionGeolocationServicesDisabled = NSLocalizedString("permission.disabled.system", value: "System location services are disabled", comment: "Geolocation Services are disabled in System Preferences")
    static let permissionOpenSystemSettings = NSLocalizedString("permission.open.settings", value: "Open System Settings", comment: "Open System Settings (to re-enable permission for the App) (macOS 13 and above)")

    static let permissionPopupTitle = NSLocalizedString("permission.popup.title", value: "Blocked Pop-ups", comment: "Title of a popup that has a list of blocked popups")
    static let permissionPopupOpenFormat = NSLocalizedString("permission.popup.open.format", value: "%@", comment: "Open %@ URL Pop-up")

    static let permissionExternalSchemeOpenFormat = NSLocalizedString("permission.externalScheme.open.format", value: "Open %@", comment: "Open %@ App Name")
    static let permissionPopupBlockedPopover = NSLocalizedString("permission.popup.blocked.popover", value: "Pop-up Blocked", comment: "Text of popver warning the user that the a pop-up as been blocked")
    static let permissionPopupLearnMoreLink = NSLocalizedString("permission.popup.learn-more.link", value: "Learn more about location services", comment: "Text of link that leads to web page with more informations about location services.")
    static let permissionPopupAllowButton = NSLocalizedString("permission.popup.allow.button", value: "Allow", comment: "Button that the user can use to authorise a web site to for, for example access location or camera and microphone etc.")

    static let privacyDashboardPermissionAsk = NSLocalizedString("dashboard.permission.ask", value: "Ask every time", comment: "Privacy Dashboard: Website should always Ask for permission for input media device access")
    static let privacyDashboardPermissionAlwaysAllow = NSLocalizedString("dashboard.permission.allow", value: "Always allow", comment: "Privacy Dashboard: Website can always access input media device")
    static let privacyDashboardPermissionAlwaysDeny = NSLocalizedString("dashboard.permission.deny", value: "Always deny", comment: "Privacy Dashboard: Website can never access input media device")
    static let permissionPopoverDenyButton = NSLocalizedString("permission.popover.deny", value: "Deny", comment: "Permission Popover: Deny Website input media device access")

    static let privacyDashboardPopupsAlwaysAsk = NSLocalizedString("dashboard.popups.ask", value: "Notify", comment: "Make PopUp Windows always asked from user for current domain")

    static let settings = NSLocalizedString("settings", value: "Settings", comment: "Menu item for opening settings")

    static let general = NSLocalizedString("preferences.general", value: "General", comment: "Title of the option to show the General preferences")
    static let sync = NSLocalizedString("preferences.sync", value: "Sync & Backup", comment: "Title of the option to show the Sync preferences")
    static let syncAutoLockPrompt = NSLocalizedString("preferences.sync.auto-lock-prompt", value: "Unlock device to setup Sync & Backup", comment: "Reason for auth when setting up Sync")
    static let syncBookmarkPausedAlertTitle = NSLocalizedString("alert.sync-bookmarks-paused-title", value: "Bookmark Sync is Paused", comment: "Title for alert shown when sync bookmarks paused for too many items")
    static let syncBookmarkPausedAlertDescription = NSLocalizedString("alert.sync-bookmarks-paused-description", value: "You've reached the maximum number of bookmarks. Please delete some bookmarks to resume sync.", comment: "Description for alert shown when sync bookmarks paused for too many items")
    static let syncCredentialsPausedAlertTitle = NSLocalizedString("alert.sync-credentials-paused-title", value: "Password Sync is Paused", comment: "Title for alert shown when sync credentials paused for too many items")
    static let syncCredentialsPausedAlertDescription = NSLocalizedString("alert.sync-credentials-paused-description", value: "You've reached the maximum number of passwords. Please delete some passwords to resume sync.", comment: "Description for alert shown when sync credentials paused for too many items")
    static let syncPausedTitle = NSLocalizedString("alert.sync.warning.sync-paused", value: "Sync & Backup is Paused", comment: "Title of the warning message")
    static let syncUnavailableMessage = NSLocalizedString("alert.sync.warning.sync-unavailable-message", value: "Sorry, but Sync & Backup is currently unavailable. Please try again later.", comment: "Data syncing unavailable warning message")
    static let syncUnavailableMessageUpgradeRequired = NSLocalizedString("alert.sync.warning.data-syncing-disabled-upgrade-required", value: "Sorry, but Sync & Backup is no longer available in this app version. Please update DuckDuckGo to the latest version to continue.", comment: "Data syncing unavailable warning message")
    static let syncErrorAlertTitle = NSLocalizedString("alert.sync-error-title", value: "Sync Error", comment: "Title for alert shown when sync error occurs")
    static let syncPausedAlertTitle = NSLocalizedString("alert.sync-paused-title", value: "Sync is Paused", comment: "Title for alert shown when sync paused for an error")
    static let syncInvalidLoginAlertDescription = NSLocalizedString("alert.sync-invalid-login-error-description", value: "Sync has been paused. If you want to continue syncing this device, reconnect using another device or your recovery code.", comment: "Description for alert shown when sync error occurs because of invalid login credentials")
    static let syncTooManyRequestsAlertDescription = NSLocalizedString("alert.sync-too-many-requests-error-description", value: "Sync & Backup is temporarily unavailable.", comment: "Description for alert shown when sync error occurs because of too many requests")
    static let syncBookmarksBadRequestAlertDescription = NSLocalizedString("alert.sync-bookmarks-bad-data-error-description", value: "Some bookmarks are formatted incorrectly or too long and were not synced.", comment: "Description for alert shown when sync error occurs because of bad data")
    static let syncCredentialsBadRequestAlertDescription = NSLocalizedString("alert.sync-credentials-bad-data-error-description", value: "Some passwords are formatted incorrectly or too long and were not synced.", comment: "Description for alert shown when sync error occurs because of bad data")
    static let syncErrorAlertAction  = NSLocalizedString("alert.sync-error-action", value: "Sync Settings", comment: "Sync error alert action button title, takes the user to the sync settings page.")

    // Sync Errors
    static let syncLimitExceededTitle = NSLocalizedString("prefrences.sync.limit-exceeded-title", value: "Sync Paused", comment: "Title for sync limits exceeded warning")
    static let syncErrorTitle = NSLocalizedString("alert.sync.warning.sync-error", value: "Sync Error", comment: "Title of the warning message that tells the user that there was an error with the sync feature.")
    static let bookmarksLimitExceededDescription = NSLocalizedString("prefrences.sync.bookmarks-limit-exceeded-description", value: "You've reached the maximum number of bookmarks. Please delete some to resume sync.", comment: "Description for sync bookmarks limits exceeded warning")
    static let credentialsLimitExceededDescription = NSLocalizedString("prefrences.sync.credentials-limit-exceeded-description", value: "You've reached the maximum number of passwords. Please delete some to resume sync.", comment: "Description for sync credentials limits exceeded warning")
    static let invalidLoginCredentialErrorDescription = NSLocalizedString("prefrences.sync.invalid-login-description", value: "Sync encountered an error. Try disabling sync on this device and then reconnect using another device or your recovery code.", comment: "Description invalid credentials error when syncing.")
    static let tooManyRequestsErrorDescription = NSLocalizedString("prefrences.sync.bookmarks.too-many-requests", value: "Sync & Backup is temporarily unavailable.", comment: "Description of too many requests error when syncing.")
    static let syncBookmarksBadRequestErrorDescription = NSLocalizedString("prefrences.sync.bad.request.description", value: "Some bookmarks are formatted incorrectly or too long and were not synced.", comment: "Description of incorrectly formatted data error when syncing.")
    static let syncCredentialsBadRequestErrorDescription = NSLocalizedString("prefrences.sync.credentials.bad.request.description", value: "Some passwords are formatted incorrectly or too long and were not synced.", comment: "Description of incorrectly formatted data error when syncing.")
    static let bookmarksLimitExceededAction = NSLocalizedString("prefrences.sync.bookmarks-limit-exceeded-action", value: "Manage Bookmarks", comment: "Button title for sync bookmarks limits exceeded warning to go to manage bookmarks")
    static let credentialsLimitExceededAction = NSLocalizedString("prefrences.sync.credentials-limit-exceeded-action", value: "Manage passwords…", comment: "Button title for sync credentials limits exceeded warning to go to manage passwords")

    static let privacyProtections = NSLocalizedString("preferences.privacy-protections", value: "Privacy Protections", comment: "The section header in Preferences representing browser features related to privacy protection")
    static let mainSettings = NSLocalizedString("preferences.main-settings", value: "Main Settings", comment: "Section header in Preferences for main settings")
    static let preferencesOn = NSLocalizedString("preferences.on", value: "On", comment: "Status indicator of a browser privacy protection feature.")
    static let preferencesOff = NSLocalizedString("preferences.off", value: "Off", comment: "Status indicator of a browser privacy protection feature.")
    static let preferencesAlwaysOn = NSLocalizedString("preferences.always-on", value: "Always On", comment: "Status indicator of a browser privacy protection feature.")
    static let duckduckgoOnOtherPlatforms = NSLocalizedString("preferences.duckduckgo-on-other-platforms", value: "DuckDuckGo on Other Platforms", comment: "Button presented to users to navigate them to our product page which presents all other products for other platforms")
    static let defaultBrowser = NSLocalizedString("preferences.default-browser", value: "Default Browser", comment: "Title of the option to show the Default Browser Preferences")
    static let privateSearch = NSLocalizedString("preferences.private-search", value: "Private Search", comment: "Title of the option to show the Private Search preferences")
    static let appearance = NSLocalizedString("preferences.appearance", value: "Appearance", comment: "Title of the option to show the Appearance preferences")
    static let dataClearing = NSLocalizedString("preferences.data-clearing", value: "Data Clearing", comment: "Title of the option to show the Data Clearing preferences")
    static let webTrackingProtection = NSLocalizedString("preferences.web-tracking-protection", value: "Web Tracking Protection", comment: "Title of the option to show the Web Tracking Protection preferences")
    static let emailProtectionPreferences = NSLocalizedString("preferences.email-protection", value: "Email Protection", comment: "Title of the option to show the Email Protection preferences")
    static let autofillEnabledFor = NSLocalizedString("preferences.autofill-enabled-for", value: "Autofill enabled in this browser for:", comment: "Label presented before the email account in email protection preferences")

    static let vpn = NSLocalizedString("preferences.vpn", value: "VPN", comment: "Title of the option to show the VPN preferences")
    static let duckPlayer = NSLocalizedString("preferences.duck-player", value: "Duck Player", comment: "Title of the option to show the Duck Player browser preferences")
    static let about = NSLocalizedString("preferences.about", value: "About", comment: "Title of the option to show the About screen")
    static let aiChat = NSLocalizedString("preferences.duckai", value: "Duck.ai", comment: "Title of the option to show Duck.ai in preferences")

    static let accessibility = NSLocalizedString("preferences.accessibility", value: "Accessibility", comment: "Title of the option to show the Accessibility browser preferences")
    static let cookiePopUpProtection = NSLocalizedString("preferences.cookie-pop-up-protection", value: "Cookie Pop-Up Protection", comment: "Title of the option to show the Cookie Pop-Up Protection preferences")
    static let downloads = NSLocalizedString("preferences.downloads", value: "Downloads", comment: "Title of the downloads browser preferences")
    static let support = NSLocalizedString("preferences.support", value: "Support", comment: "Open support page")

    static let isDefaultBrowser = NSLocalizedString("preferences.default-browser.active", value: "DuckDuckGo is your default browser", comment: "Indicate that the browser is the default")
    static let isNotDefaultBrowser = NSLocalizedString("preferences.default-browser.inactive", value: "DuckDuckGo is not your default browser.", comment: "Indicate that the browser is not the default")
    static let makeDefaultBrowser = NSLocalizedString("preferences.default-browser.button.make-default", value: "Make DuckDuckGo Default…", comment: "represents a prompt message asking the user to make DuckDuckGo their default browser.")
    static let shortcuts = NSLocalizedString("preferences.shortcuts", value: "Shortcuts", comment: "Name of the preferences section related to shortcuts")
    static let isAddedToDock = NSLocalizedString("preferences.is-added-to-dock", value: "DuckDuckGo is added to the Dock.", comment: "Indicates that the browser is added to the macOS system Dock")
    static let isNotAddedToDock = NSLocalizedString("preferences.not-added-to-dock", value: "DuckDuckGo is not added to the Dock.", comment: "Indicate that the browser is not added to macOS system Dock")
    static let addToDock = NSLocalizedString("preferences.add-to-dock", value: "Add to Dock…", comment: "Action button to add the app to the Dock")
    static let addDuckDuckGoToDock = NSLocalizedString("preferences.add-to-dock", value: "Add DuckDuckGo To Dock…", comment: "Action button to add the app to the Dock")
    static let onStartup = NSLocalizedString("preferences.on-startup", value: "On Startup", comment: "Name of the preferences section related to app startup")
    static let reopenAllWindowsFromLastSession = NSLocalizedString("preferences.reopen-windows", value: "Reopen all windows from last session", comment: "Option to control session restoration")
    static let showHomePage = NSLocalizedString("preferences.show-home", value: "Open a new window", comment: "Option to control session startup")

    static let homePage = NSLocalizedString("preferences-homepage.title", value: "Homepage", comment: "Title for Homepage section in settings")
    static let homePageDescription = NSLocalizedString("preferences-homepage.description", value: "When navigating home or opening new windows.", comment: "Homepage behavior description")
    static let newTab = NSLocalizedString("preferences-homepage-newTab", value: "New Tab page", comment: "Option to open a new tab")
    static let specificPage = NSLocalizedString("preferences-homepage-customPage", value: "Specific page", comment: "Option to control Specific Home Page")
    static let setPage = NSLocalizedString("preferences-homepage-set-page", value: "Set Page…", comment: "Option to control the Specific Page")

    static let setHomePage = NSLocalizedString("preferences-homepage-set-homePage", value: "Set Homepage", comment: "Set Homepage dialog title")
    static let addressLabel = NSLocalizedString("preferences-homepage-address", value: "Address:", comment: "Homepage address field label")

    static let tabs = NSLocalizedString("preferences-tabs.title", value: "Tabs", comment: "Title for tabs section in settings")
    static let preferNewTabsToWindows = NSLocalizedString("preferences-tabs.prefer.new.tabs.to.windows", value: "Open links in new tabs instead of new windows whenever possible", comment: "Option to prefer opening new tabs instead of windows when opening links")
    static let switchToNewTabWhenOpened = NSLocalizedString("preferences-tabs.switch.tab.when.opened", value: "When opening links, switch to the new tab or window immediately", comment: "Option to switch to a new tab/window when it is opened")
    static let newTabPositionTitle = NSLocalizedString("preferences-tabs.new.tab.position.title", value: "When creating a new tab", comment: "Title for new tab positioning")

    static func newTabPositionMode(for position: NewTabPosition) -> String {
        switch position {
        case .atEnd:
            return NSLocalizedString("context.menu.new.tab.mode.at.end", value: "Add to the right of other tabs", comment: "Preferences > Tabs > At end of list")
        case .nextToCurrent:
            return NSLocalizedString("context.menu.new.tab.mode.next.to.current", value: "Add to the right of the current tab", comment: "Preferences > Tabs > Next to current tab")
        }
    }

    static func homeButtonMode(for position: HomeButtonPosition) -> String {
        switch position {
        case .hidden:
            return NSLocalizedString("context.menu.home.button.mode.hide", value: "Hide", comment: "Preferences > Home Button > None item")
        case .left:
            return NSLocalizedString("context.menu.home.button.mode.left", value: "Show left of the back button", comment: "Preferences > Home Button > left position item")
        case .right:
            return NSLocalizedString("context.menu.home.button.mode.right", value: "Show right of the reload button", comment: "Preferences > Home Button > right position item")
        }
    }

    static let theme = NSLocalizedString("preferences.appearance.theme", value: "Theme", comment: "Theme preferences")
    static let themeLight = NSLocalizedString("preferences.appearance.theme.light", value: "Light", comment: "In the preferences for themes, the option to select for activating light mode in the app.")
    static let themeDark = NSLocalizedString("preferences.appearance.theme.dark", value: "Dark", comment: "In the preferences for themes, the option to select for activating dark mode in the app.")
    static let themeSystem = NSLocalizedString("preferences.appearance.theme.system", value: "System", comment: "In the preferences for themes, the option to select for use the change the mode based on the system preferences.")
    static let addressBar = NSLocalizedString("preferences.appearance.address-bar", value: "Address Bar", comment: "Theme preferences")
    static let showFullWebsiteAddress = NSLocalizedString("preferences.appearance.show-full-url", value: "Full website address", comment: "Option to show full URL in the address bar")
    static let showAutocompleteSuggestions = NSLocalizedString("preferences.appearance.show-autocomplete-suggestions", value: "Autocomplete suggestions", comment: "Option to show autocomplete suggestions in the address bar")
    static let customizeBackground = NSLocalizedString("preferences.appearance.customize-background", value: "Customize Background", comment: "Button to open home page background customization options")
    static let zoomPickerTitle = NSLocalizedString("preferences.appearance.zoom-picker", value: "Default page zoom", comment: "Default page zoom picker title")
    static let defaultZoomPageMoreOptionsItem = NSLocalizedString("more-options.zoom.default-zoom-page", value: "Change Default Page Zoom…", comment: "Default page zoom picker title")
    static let autofill = NSLocalizedString("preferences.autofill", value: "Passwords", comment: "Show Autofill preferences")

    static let aboutDuckDuckGo = NSLocalizedString("preferences.about.about-duckduckgo", value: "About DuckDuckGo", comment: "About screen")
    static let duckduckgoTagline = NSLocalizedString("preferences.about.duckduckgo-tagline", value: "Your protection, our priority.", comment: "About screen")
    static let setAsDefaultBrowser = NSLocalizedString("preferences.set-as-default", value: "Set DuckDuckGo As Default Browser", comment: "Menu option to set the browser as default")
    static let aboutUnsupportedDeviceInfo1 = NSLocalizedString("preferences.about.unsupported-device-info1", value: "DuckDuckGo is no longer providing browser updates for your version of macOS.", comment: "This string represents a message informing the user that DuckDuckGo is no longer providing browser updates for their version of macOS")
    static func aboutUnsupportedDeviceInfo2(version: String) -> String {
        let localized = NSLocalizedString("preferences.about.unsupported-device-info2", value: "Please update to macOS %@ or later to use the most recent version of DuckDuckGo. You can also keep using your current version of the browser, but it will not receive further updates.", comment: "Copy in section that tells the user to update their macOS version since their current version is unsupported")
        return String(format: localized, version)
    }
    static let aboutUnsupportedDeviceInfo2Part1 = "Please"
    static func aboutUnsupportedDeviceInfo2Part2(version: String) -> String {
        return String(format: "update to macOS %@", version)
    }
    static let aboutUnsupportedDeviceInfo2Part3 = "or later to use the most recent version"
    static let aboutUnsupportedDeviceInfo2Part4 = "of DuckDuckGo. You can also keep using your current version of the browser, but it will not receive further updates."
    static let unsupportedDeviceInfoAlertHeader = NSLocalizedString("unsupported.device.info.alert.header", value: "Your version of macOS is no longer supported.", comment: "his string represents the header for an alert informing the user that their version of macOS is no longer supported")

    static func moreAt(url: String) -> String {
        let localized = NSLocalizedString("preferences.about.more-at", value: "More at %@", comment: "Link to the about page")
        return String(format: localized, url)
    }

    static let sendFeedback = NSLocalizedString("preferences.about.send-feedback", value: "Send Feedback", comment: "Feedback button in the about preferences page")

    static let feedbackDisclaimer = NSLocalizedString("feedback.disclaimer", value: "Reports sent to DuckDuckGo are 100% anonymous and only include your message, the DuckDuckGo browser version, and your macOS version.", comment: "Disclaimer in breakage form - a form that users can submit to say that a website is not working properly in DuckDuckGo")

    static let feedbackBugDescription = NSLocalizedString("feedback.bug.description", value: "Please describe the problem in as much detail as possible:", comment: "Label in the feedback form that users can submit to say that a website is not working properly in DuckDuckGo")
    static let feedbackFeatureRequestDescription = NSLocalizedString("feedback.feature.request.description", value: "What feature would you like to see?", comment: "Label in the feedback form for feature requests.")
    static let feedbackOtherDescription = NSLocalizedString("feedback.other.description", value: "Please give us your feedback:", comment: "Label in the feedback form")

    static func versionLabel(version: String, build: String) -> String {
        let localized = NSLocalizedString("version",
                                          value: "Version %@ (%@)",
                                          comment: "Displays the version and build numbers")
        return String(format: localized, version, build)
    }

    static let privacyPolicy = NSLocalizedString("preferences.about.privacy-policy", value: "Privacy Policy", comment: "Link to privacy policy page")

    // MARK: - Login Import & Export

    static let importLoginsCSV = NSLocalizedString("import.logins.csv.title", value: "CSV Passwords File (for other browsers)", comment: "Title text for the CSV importer")
    static let importBookmarksHTML = NSLocalizedString("import.bookmarks.html.title", value: "HTML Bookmarks File (for other browsers)", comment: "Title text for the HTML Bookmarks importer")
    static let importBookmarksSelectHTMLFile = NSLocalizedString("import.bookmarks.select-html-file", value: "Select Bookmarks HTML File…", comment: "Button text for selecting HTML Bookmarks file")
    static let importLoginsSelectCSVFile = NSLocalizedString("import.logins.select-csv-file", value: "Select Passwords CSV File…", comment: "Button text for selecting a CSV file")
    static func importLoginsSelectCSVFile(from source: DataImport.Source) -> String {
        String(format: NSLocalizedString("import.logins.select-csv-file.source", value: "Select %@ CSV File…", comment: "Button text for selecting a CSV file exported from (LastPass or Bitwarden or 1Password - %@)"), source.importSourceName)
    }

    static func importNoDataBookmarksSubtitle(from source: DataImport.Source) -> String {
        String(format: NSLocalizedString("import.nodata.bookmarks.subtitle", value: "If you have %@ bookmarks, try importing them manually instead.", comment: "Data import error subtitle: suggestion to import Bookmarks manually by selecting a CSV or HTML file. The placeholder here represents the source browser, e.g Firefox."), source.importSourceName)
    }
    static func importNoDataPasswordsSubtitle(from source: DataImport.Source) -> String {
        String(format: NSLocalizedString("import.nodata.passwords.subtitle", value: "If you have %@ passwords, try importing them manually instead.", comment: "Data import error subtitle: suggestion to import passwords manually by selecting a CSV or HTML file. The placeholder here represents the source browser, e.g Firefox."), source.importSourceName)
    }

    static let importLoginsPasswords = NSLocalizedString("import.logins.passwords", value: "Passwords", comment: "Title text for the Passwords import option")
    static let importLoginsPasswordsExplainer = NSLocalizedString("import.logins.passwords.explainer", value: "Passwords are encrypted. Viewing them or filling out forms requires Touch ID or a password. Nobody but you can see your passwords, not even us. Find Passwords in DuckDuckGo Settings > Passwords & Autofill.", comment: "Explanatory text for the Passwords import option to alleviate security concerns and explain usage.")
    static let importLoginsPasswordsExplainerAutolockOff = NSLocalizedString("import.logins.passwords.explainer.autolock.off", value: "Passwords are encrypted. We recommend setting up Auto-lock to keep your passwords even more secure. Set it up in DuckDuckGo Settings > Passwords & Autofill.", comment: "Explanatory text for the Passwords import option to alleviate security concerns and explain usage when autolock is disabled")

    static let importBookmarksButtonTitle = NSLocalizedString("bookmarks.import.button.title", value: "Import", comment: "Button text to open bookmark import dialog")
    static let initiateImport = NSLocalizedString("import.data.initiate", value: "Import", comment: "Button text for importing data")
    static let skipBookmarksImport = NSLocalizedString("import.data.skip.bookmarks", value: "Skip bookmarks", comment: "Button text to skip bookmarks manual import")
    static let skipPasswordsImport = NSLocalizedString("import.data.skip.passwords", value: "Skip passwords", comment: "Button text to skip bookmarks manual import")
    static let skip = NSLocalizedString("import.data.skip", value: "Skip", comment: "Button text to skip an import step")
    static let done = NSLocalizedString("import.data.done", value: "Done", comment: "Button text for finishing the data import")
    static let manualImport = NSLocalizedString("import.data.manual", value: "Manual import…", comment: "Button text for initiating manual data import using a HTML or CSV file when automatic import has failed")

    static let dataImportAlertImport = NSLocalizedString("import.data.alert.import", value: "Import", comment: "Import button for data import alerts")
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

    static let bookmarkImportSafariRequestPermissionButtonTitle = NSLocalizedString("import.bookmarks.safari.permission-button.title", value: "Select Safari Folder…", comment: "Text for the Safari data import permission button")

    static let bookmarkImportBookmarks = NSLocalizedString("import.bookmarks.bookmarks", value: "Bookmarks", comment: "Title text for the Bookmarks import option")

    static let importShortcutsBookmarksTitle = NSLocalizedString("import.shortcuts.bookmarks.title", value: "Show Bookmarks Bar", comment: "Title for the setting to enable the bookmarks bar")
    static let importShortcutsBookmarksSubtitle = NSLocalizedString("import.shortcuts.bookmarks.subtitle", value: "Put your favorite bookmarks in easy reach", comment: "Description for the setting to enable the bookmarks bar")
    static let importShortcutsPasswordsTitle = NSLocalizedString("import.shortcuts.passwords.title", value: "Show Passwords Shortcut", comment: "Title for the setting to enable the passwords shortcut")
    static let importShortcutsPasswordsSubtitle = NSLocalizedString("import.shortcuts.passwords.subtitle", value: "Keep passwords nearby in the address bar", comment: "Description for the setting to enable the passwords shortcut")

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
    static let downloadBytesLoadedFormat = NSLocalizedString("downloads.bytes.format", value: "%@ of %@", comment: "Number of bytes out of total bytes downloaded (1Mb of 2Mb)")
    static let downloadSpeedFormat = NSLocalizedString("downloads.speed.format", value: "%@/s", comment: "Download speed format (1Mb/sec)")
    static let downloadsErrorMessage = NSLocalizedString("downloads.error.message.for.specific.os", value: "The download failed because of a known issue on macOS 14.7.1 and 15.0.1. Update to macOS 15.1 and try downloading again.", comment: "This error message will appear in an error banner when users cannot download files on macOS 14.7.1 or 15.0.1")
    static let downloadsErrorSandboxCallToAction = NSLocalizedString("downloads.error.cta.sandbox", value: "How To Update", comment: "Call to action for the OS specific downloads issue")
    static let downloadsErrorNonSandboxCallToAction = NSLocalizedString("downloads.error.cta.non-sandbox", value: "Open Settings", comment: "Call to action for the OS specific downloads issue")

    static let cancelDownloadToolTip = NSLocalizedString("downloads.tooltip.cancel", value: "Cancel Download", comment: "Mouse-over tooltip for Cancel Download button")
    static let restartDownloadToolTip = NSLocalizedString("downloads.tooltip.restart", value: "Restart Download", comment: "Mouse-over tooltip for Restart Download button")
    static let redownloadToolTip = NSLocalizedString("downloads.tooltip.redownload", value: "Download Again", comment: "Mouse-over tooltip for Download [deleted file] Again button")
    static let revealToolTip = NSLocalizedString("downloads.tooltip.reveal", value: "Show in Finder", comment: "Mouse-over tooltip for Show in Finder button")

    static let downloadsActiveAlertTitle = NSLocalizedString("downloads.active.alert.title", value: "A download is in progress.", comment: "Alert title when trying to quit application while files are being downloaded")
    static let downloadsActiveAlertMessageFormat = NSLocalizedString("downloads.active.alert.message.format", value: "Are you sure you want to quit?\n\nDuckDuckGo is currently downloading “%@”%@. If you quit now, DuckDuckGo won‘t finish downloading %@.", comment: "Alert text format when trying to quit application while file “filename (%@)”[, and others (%@)] are being downloaded; If you quit now, DuckDuckGo won‘t finish downloading [this file|these files](%@).")
    static let downloadsActiveAlertMessageAndOthers = NSLocalizedString("downloads.active.alert.message.and.others", value: ", and other files", comment: "Alert text format element for “, and other files”")
    static let downloadsActiveAlertMessageThisFile = NSLocalizedString("downloads.active.alert.message.this.file", value: "this file", comment: "Alert text format element for “DuckDuckGo won‘t finish downloading ->this file<-”")
    static let downloadsActiveAlertMessageTheseFiles = NSLocalizedString("downloads.active.alert.message.these.files", value: "these files", comment: "Alert text format element for “DuckDuckGo won‘t finish downloading ->these file<-”")

    static let downloadsActiveInFireWindowAlertMessageFormat = NSLocalizedString("fire-window.downloads.active.alert.message.format", value: "Are you sure you want to close the Fire Window?\n\nDuckDuckGo is currently downloading “%@”%@. If you close the Fire Window, DuckDuckGo will delete %@.", comment: "Alert text format when trying to close a Fire Window while file “filename (%@)”[, and others (%@)] are being downloaded in it. If you close the Fire Window, DuckDuckGo will delete [this file|these files](%@).")

    static let exportLoginsFailedMessage = NSLocalizedString("export.logins.failed.message", value: "Failed to Export Passwords", comment: "Alert title when exporting login data fails")
    static let exportLoginsFailedInformative = NSLocalizedString("export.logins.failed.informative", value: "Please check that no file exists at the location you selected.", comment: "Alert message when exporting login data fails")
    static let exportBookmarksFailedMessage = NSLocalizedString("export.bookmarks.failed.message", value: "Failed to Export Bookmarks…", comment: "Alert title when exporting login data fails")
    static let exportBookmarksFailedInformative = NSLocalizedString("export.bookmarks.failed.informative", value: "Please check that no file exists at the location you selected.", comment: "Alert message when exporting bookmarks fails")

    static let exportLoginsFileNameSuffix = NSLocalizedString("export.logins.file.name.suffix", value: "Passwords", comment: "The last part of the suggested file name for exporting logins")
    static let exportBookmarksFileNameSuffix = NSLocalizedString("export.bookmarks.file.name.suffix", value: "Bookmarks", comment: "The last part of the suggested file for exporting bookmarks")
    static let exportLoginsWarning = NSLocalizedString("export.logins.warning", value: "This file contains your passwords in plain text and should be saved in a secure location and deleted when you are done.\nAnyone with access to this file will be able to read your passwords.", comment: "Warning text presented when exporting logins.")

    static let onboardingWelcomeTitle = NSLocalizedString("onboarding.welcome.title", value: "Welcome to DuckDuckGo!", comment: "General welcome to the app title")
    static let onboardingWelcomeText = NSLocalizedString("onboarding.welcome.text", value: "Tired of being tracked online? You've come to the right place 👍\n\nI'll help you stay private️ as you search and browse the web. Trackers be gone!", comment: "Detailed welcome to the app text")
    static let onboardingImportDataText = NSLocalizedString("onboarding.importdata.text", value: "First, let me help you import your bookmarks 📖 and passwords 🔑 from those less private browsers.", comment: "Call to action to import data from other browsers")
    static let onboardingSetDefaultText = NSLocalizedString("onboarding.setdefault.text", value: "Next, try setting DuckDuckGo as your default️ browser, so you can open links with peace of mind, every time.", comment: "Call to action to set the browser as default")
    static let onboardingAddToDockText = NSLocalizedString("onboarding.addtodock.text", value: "One last thing. Want to keep DuckDuckGo in your Dock so the browser's always within reach?", comment: "Call to action to add the DuckDuckGo app icon to the macOS system dock")
    static let onboardingStartBrowsingText = NSLocalizedString("onboarding.startbrowsing.text", value: "You’re all set!\n\nWant to see how I protect you? Try visiting one of your favorite sites 👆\n\nKeep watching the address bar as you go. I’ll be blocking trackers and upgrading the security of your connection when possible\u{00A0}🔒", comment: "Call to action to start using the app as a browser")
    static let onboardingStartBrowsingAddedToDockText = NSLocalizedString("onboarding.startbrowsing.added-to-dock.text", value: "You’re all set! You can find me hanging out in the Dock anytime.\n\nWant to see how I protect you? Try visiting one of your favorite sites 👆\n\nKeep watching the address bar as you go. I’ll be blocking trackers and upgrading the security of your connection when possible\u{00A0}🔒", comment: "Call to action to start using the app as a browser")

    static let onboardingStartButton = NSLocalizedString("onboarding.welcome.button", value: "Get Started", comment: "Start the onboarding flow")
    static let onboardingImportDataButton = NSLocalizedString("onboarding.importdata.button", value: "Import", comment: "Launch the import data UI")
    static let onboardingSetDefaultButton = NSLocalizedString("onboarding.setdefault.button", value: "Let's Do It!", comment: "Launch the set default UI")
    static let onboardingAddToDockButton = NSLocalizedString("onboarding.addtodock.button", value: "Keep in Dock", comment: "Button label to add application to the macOS system dock")
    static let onboardingNotNowButton = NSLocalizedString("onboarding.notnow.button", value: "Maybe Later", comment: "Skip a step of the onboarding flow")

    static func importingBookmarks(_ numberOfBookmarks: Int?) -> String {
        if let numberOfBookmarks, numberOfBookmarks > 0 {
            let localized = NSLocalizedString("import.bookmarks.number.progress.text", value: "Importing bookmarks (%d)…", comment: "Operation progress info message about %d number of bookmarks being imported")
            return String(format: localized, numberOfBookmarks)
        } else {
            return NSLocalizedString("import.bookmarks.indefinite.progress.text", value: "Importing bookmarks…", comment: "Operation progress info message about indefinite number of bookmarks being imported")
        }
    }

    static func importingPasswords(_ numberOfPasswords: Int?) -> String {
        if let numberOfPasswords, numberOfPasswords > 0 {
            let localized = NSLocalizedString("import.passwords.number.progress.text", value: "Importing passwords (%d)…", comment: "Operation progress info message about %d number of passwords being imported")
            return String(format: localized, numberOfPasswords)
        } else {
            return NSLocalizedString("import.passwords.indefinite.progress.text", value: "Importing passwords…", comment: "Operation progress info message about indefinite number of passwords being imported")
        }
    }

    static let moreOrLessCollapse = NSLocalizedString("more.or.less.collapse", value: "Show Less", comment: "For collapsing views to show less.")
    static let moreOrLessExpand = NSLocalizedString("more.or.less.expand", value: "Show More", comment: "For expanding views to show more.")

    static let defaultBrowserPromptMessage = NSLocalizedString("default.browser.prompt.message", value: "Make DuckDuckGo your default browser", comment: "represents a prompt message asking the user to make DuckDuckGo their default browser.")
    static let defaultBrowserPromptButton = NSLocalizedString("default.browser.prompt.button", value: "Set Default…", comment: "represents a prompt message asking the user to make DuckDuckGo their default browser.")

    static let homePageProtectionSummaryInfo = NSLocalizedString("home.page.protection.summary.info", value: "No recent activity", comment: "This string represents a message in the protection summary on the home page, indicating that there is no recent activity")
    static func homePageProtectionSummaryMessage(numberOfTrackersBlocked: Int) -> String {
        let localized = NSLocalizedString("home.page.protection.summary.message",
                                          value: "%@ tracking attempts blocked",
                                          comment: "The number of tracking attempts blocked in the last 7 days, shown on a new tab, translate as: Tracking attempts blocked: %@")
        return String(format: localized, NumberFormatter.localizedString(from: NSNumber(value: numberOfTrackersBlocked), number: .decimal))
    }
    static let homePageProtectionDurationInfo = NSLocalizedString("home.page.protection.duration", value: "PAST 7 DAYS", comment: "Past 7 days in uppercase.")

    static let homePageEmptyStateItemTitle = NSLocalizedString("home.page.empty.state.item.title", value: "Recently visited sites appear here", comment: "This string represents the title for an empty state item on the home page, indicating that recently visited sites will appear here")
    static let homePageEmptyStateItemMessage = NSLocalizedString("home.page.empty.state.item.message", value: "Keep browsing to see how many trackers were blocked", comment: "This string represents the message for an empty state item on the home page, encouraging the user to keep browsing to see how many trackers were blocked")
    static let homePageNoTrackersFound = NSLocalizedString("home.page.no.trackers.found", value: "No trackers found", comment: "This string represents a message on the home page indicating that no trackers were found")
    static let homePageNoTrackersBlocked = NSLocalizedString("home.page.no.trackers.blocked", value: "No trackers blocked", comment: "This string represents a message on the home page indicating that no trackers were blocked")
    static let homePageBurnFireproofSiteAlert = NSLocalizedString("home.page.burn.fireproof.site.alert", value: "History will be cleared for this site, but related data will remain, because this site is Fireproof", comment: "Message for an alert displayed when trying to burn a fireproof website")
    static let homePageClearHistory = NSLocalizedString("home.page.clear.history", value: "Clear History", comment: "Button caption for the burn fireproof website alert")

    static let tooltipAddToFavorites = NSLocalizedString("tooltip.addToFavorites", value: "Add to Favorites", comment: "Tooltip for add to favorites button")

    static func tooltipClearHistoryAndData(domain: String) -> String {
        let localized = NSLocalizedString("tooltip.clearHistoryAndData",
                                          value: "Clear browsing history and data for %@",
                                          comment: "Tooltip for burn button where %@ is the domain")
        return String(format: localized, domain)
    }
    static func tooltipClearHistory(domain: String) -> String {
        let localized = NSLocalizedString("tooltip.clearHistory",
                                          value: "Clear browsing history for %@",
                                          comment: "Tooltip for burn button where %@ is the domain")
        return String(format: localized, domain)
    }

    static let recentlyClosedWindowMenuItem = NSLocalizedString("n.more.tabs", value: "Window with multiple tabs (%d)", comment: "String in Recently Closed menu item for recently closed browser window and number of tabs contained in the closed window")

    static let reopenLastClosedTab = NSLocalizedString("reopen.last.closed.tab", value: "Reopen Last Closed Tab", comment: "This string represents an action to reopen the last closed tab in the browser")
    static let reopenLastClosedWindow = NSLocalizedString("reopen.last.closed.window", value: "Reopen Last Closed Window", comment: "This string represents an action to reopen the last closed window in the browser")
    static let cookiePopupManagedNotification = NSLocalizedString("notification.badge.cookiesmanaged", value: "Cookies Managed", comment: "Notification that appears when browser automatically handle cookies")
    static let cookiePopupHiddenNotification = NSLocalizedString("notification.badge.popuphidden", value: "Pop-up Hidden", comment: "Notification that appears when browser cosmetically hides a cookie popup")

    static let autoconsentModalTitle = NSLocalizedString("autoconsent.modal.title", value: "Looks like this site has a cookie pop-up 👇", comment: "Title for modal asking the user to auto manage cookies")
    static let autoconsentFromSetUpModalTitle = NSLocalizedString("autoconsent.from.setup.modal.title", value: "Want DuckDuckGo to handle cookie pop-ups?", comment: "Title for modal asking the user to auto manage cookies")

    static let autoconsentModalBody = NSLocalizedString("autoconsent.modal.body", value: "Want me to handle these for you? I can try to minimize cookies, maximize privacy, and hide pop-ups like these.", comment: "Body for modal asking the user to auto manage cookies")
    static let autoconsentFromSetUpModalBody = NSLocalizedString("autoconsent.from.setup.modal.body", value: "When we detect cookie pop-ups on sites you visit, we can try to select the most private settings available and hide pop-ups like this.", comment: "Body for modal asking the user to auto manage cookies")

    static let autoconsentModalConfirmButton = NSLocalizedString("autoconsent.modal.cta.confirm", value: "Manage Cookie Pop-ups", comment: "Confirm button for modal asking the user to auto manage cookies")
    static let autoconsentFromSetUpModalConfirmButton = NSLocalizedString("autoconsent.from.setup.modal.cta.confirm", value: "Handle Pop-ups For Me", comment: "Confirm button for modal asking the user to auto manage cookies")
    static let autoconsentModalDenyButton = NSLocalizedString("autoconsent.modal.cta.deny", value: "No Thanks", comment: "Deny button for modal asking the user to auto manage cookies")

    static let clearThisHistoryMenuItem = NSLocalizedString("history.menu.clear.this.history", value: "Clear This History…", comment: "Menu item to clear parts of history and data")
    static let recentlyVisitedMenuSection = NSLocalizedString("history.menu.recently.visited", value: "Recently Visited", comment: "Section header of the history menu")
    static let olderMenuItem = NSLocalizedString("history.menu.older", value: "Older…", comment: "Menu item representing older history")

    static let clearAllDataQuestion = NSLocalizedString("history.menu.clear.all.history.question", value: "Clear all history and \nclose all tabs?", comment: "Alert with the confirmation to clear all history and data")
    static let clearAllDataDescription = NSLocalizedString("history.menu.clear.all.history.description", value: "Cookies and site data for all sites will also be cleared, unless the site is Fireproof.", comment: "Description in the alert with the confirmation to clear all data")

    static let clearDataHeader = NSLocalizedString("history.menu.clear.data.question", value: "Clear History for %@?", comment: "Alert with the confirmation to clear all data")
    static let clearDataDescription = NSLocalizedString("history.menu.clear.data.description", value: "Cookies and other data for sites visited on this day will also be cleared unless the site is Fireproof. History from other days will not be cleared.", comment: "Description in the alert with the confirmation to clear browsing history")
    static let clearDataTodayHeader = NSLocalizedString("history.menu.clear.data.today.question", value: "Clear history for today \nand close all tabs?", comment: "Alert with the confirmation to clear all data")
    static let clearDataTodayDescription = NSLocalizedString("history.menu.clear.data.today.description", value: "Cookies and other data for sites visited today will also be cleared unless the site is Fireproof. History from other days will not be cleared.", comment: "Description in the alert with the confirmation to clear browsing history")

    static let showBookmarksBar = NSLocalizedString("bookmarks.bar.show", value: "Bookmarks Bar", comment: "Menu item for showing the bookmarks bar")
    static let showBookmarksBarPreference = NSLocalizedString("bookmarks.bar.preferences.show", value: "Show Bookmarks Bar", comment: "Preference item for showing the bookmarks bar")
    static let showBookmarksBarAlways = NSLocalizedString("bookmarks.bar.show.always", value: "Always show", comment: "Preference for always showing the bookmarks bar")
    static let showBookmarksBarNewTabOnly = NSLocalizedString("bookmarks.bar.show.new-tab-only", value: "Only show on New Tab", comment: "Preference for only showing the bookmarks bar on new tab")
    static let bookmarksBarFolderEmpty = NSLocalizedString("bookmarks.bar.folder.empty", value: "Empty", comment: "Empty state for a bookmarks bar folder")
    static let bookmarksBarContextMenuCopy = NSLocalizedString("bookmarks.bar.context-menu.copy", value: "Copy", comment: "Copy menu item for the bookmarks bar context menu")
    static let bookmarksBarContextMenuDelete = NSLocalizedString("bookmarks.bar.context-menu.delete", value: "Delete", comment: "Delete menu item for the bookmarks bar context menu")
    static let bookmarksBarContextMenuMoveToEnd = NSLocalizedString("bookmarks.bar.context-menu.move-to-end", value: "Move to End", comment: "Move to End menu item for the bookmarks bar context menu")

    static let inviteDialogGetStartedButton = NSLocalizedString("invite.dialog.get.started.button", value: "Get Started", comment: "Get Started button on an invite dialog")
    static let inviteDialogUnrecognizedCodeMessage = NSLocalizedString("invite.dialog.unrecognized.code.message", value: "We didn’t recognize this Invite Code.", comment: "Message to show after user enters an unrecognized invite code")

    // MARK: - Bitwarden

    static let passwordManager = NSLocalizedString("password.manager", value: "Password Manager", comment: "Section header")
    static let bitwardenPreferencesUnableToConnect = NSLocalizedString("bitwarden.preferences.unable-to-connect", value: "Unable to find or connect to Bitwarden", comment: "Dialog telling the user Bitwarden (a password manager) is not available")
    static let bitwardenPreferencesCompleteSetup = NSLocalizedString("bitwarden.preferences.complete-setup", value: "Complete Setup…", comment: "action option that prompts the user to complete the setup process in Bitwarden preferences")
    static let bitwardenPreferencesOpenBitwarden = NSLocalizedString("bitwarden.preferences.open-bitwarden", value: "Open Bitwarden", comment: "Button to open Bitwarden app")
    static let bitwardenPreferencesUnlock = NSLocalizedString("bitwarden.preferences.unlock", value: "Unlock Bitwarden", comment: "Asks the user to unlock the password manager Bitwarden")
    static let bitwardenPreferencesRun = NSLocalizedString("bitwarden.preferences.run", value: "Bitwarden app not running", comment: "Warns user that the password manager Bitwarden app is not running")
    static let bitwardenError = NSLocalizedString("bitwarden.error", value: "Unable to find or connect to Bitwarden", comment: "This message appears when the application is unable to find or connect to Bitwarden, indicating a connection issue.")
    static let bitwardenNotInstalled = NSLocalizedString("bitwarden.not.installed", value: "Bitwarden app is not installed", comment: "")
    static let bitwardenOldVersion = NSLocalizedString("bitwarden.old.version", value: "Please update Bitwarden to the latest version", comment: "Message that warns user they need to update their password manager Bitwarden app vesion")
    static let bitwardenIncompatible = NSLocalizedString("bitwarden.incompatible", value: "The following Bitwarden versions are incompatible with DuckDuckGo: v2024.10.0, v2024.10.1, v2024.10.2. Please downgrade to an older version by following these steps:", comment: "Message that warns user that specific Bitwarden app vesions are not compatible with this app")
    static let bitwardenIncompatibleStep1 = NSLocalizedString("bitwarden.incompatible.step.1", value: "Download v2024.9.0", comment: "First step to downgrade Bitwarden")
    static let bitwardenIncompatibleStep2 = NSLocalizedString("bitwarden.incompatible.step.2", value: "2. Open the downloaded DMG file and drag the Bitwarden application to\nthe /Applications folder.", comment: "Second step to downgrade Bitwarden")
    static let bitwardenIntegrationNotApproved = NSLocalizedString("bitwarden.integration.not.approved", value: "Integration with DuckDuckGo is not approved in Bitwarden app", comment: "While the user tries to connect the DuckDuckGo Browser to password manager Bitwarden This message indicates that the integration with DuckDuckGo has not been approved in the Bitwarden app.")
    static let bitwardenMissingHandshake = NSLocalizedString("bitwarden.missing.handshake", value: "Missing handshake", comment: "While the user tries to connect the DuckDuckGo Browser to password manager Bitwarden This message indicates a missing handshake (a way for two devices or systems to say hello to each other and agree to communicate or exchange information).")
    static let bitwardenWaitingForHandshake = NSLocalizedString("bitwarden.waiting.for.handshake", value: "Waiting for the handshake approval in Bitwarden app", comment: "While the user tries to connect the DuckDuckGo Browser to password manager Bitwarden This message indicates the system is waiting for the handshake (a way for two devices or systems to say hello to each other and agree to communicate or exchange information).")
    static let bitwardenCantAccessContainer = NSLocalizedString("bitwarden.cant.access.container", value: "DuckDuckGo needs permission to access Bitwarden. You can grant DuckDuckGo Full Disk Access in System Settings, or switch back to the built-in password manager.", comment: "Requests user Full Disk access in order to access password manager Birwarden")
    static let bitwardenHanshakeNotApproved = NSLocalizedString("bitwarden.handshake.not.approved", value: "Handshake not approved in Bitwarden app", comment: "It appears in a dialog when the users are connecting to Bitwardern and shows the status of the action. This message indicates that the handshake process was not approved in the Bitwarden app.")
    static let bitwardenConnecting = NSLocalizedString("bitwarden.connecting", value: "Connecting to Bitwarden", comment: "It appears in a dialog when the users are connecting to Bitwardern and shows the status of the action, in this case we are in the progress of connecting the browser to the Bitwarden password maanger.")
    static let bitwardenWaitingForStatusResponse = NSLocalizedString("bitwarden.waiting.for.status.response", value: "Waiting for the status response from Bitwarden", comment: "It appears in a dialog when the users are connecting to Bitwardern and shows the status of the action, in this case that the application is currently waiting for a response from the Bitwarden service.")

    static let connectToBitwarden = NSLocalizedString("bitwarden.connect.title", value: "Connect to Bitwarden", comment: "Title for the Bitwarden onboarding flow")

    static let connectToBitwardenDescription = NSLocalizedString("bitwarden.connect.description", value: "We’ll walk you through connecting to Bitwarden, so you can use it in DuckDuckGo.", comment: "Description for when the user wants to connect the browser to the password manager Bitwarned.")

    static let connectToBitwardenPrivacy = NSLocalizedString("bitwarden.connect.privacy", value: "Privacy", comment: "")
    static let installBitwarden = NSLocalizedString("bitwarden.install", value: "Install Bitwarden", comment: "Button to install Bitwarden app")
    static let installBitwardenInfo = NSLocalizedString("bitwarden.install.info", value: "To begin setup, first install Bitwarden from the App Store.", comment: "Setup of the integration with Bitwarden app")
    static let afterBitwardenInstallationInfo = NSLocalizedString("after.bitwarden.installation.info", value: "After installing, return to DuckDuckGo to complete the setup.", comment: "Setup of the integration with Bitwarden app")
    static let bitwardenAppFound = NSLocalizedString("bitwarden.app.found", value: "Bitwarden app found!", comment: "Setup of the integration with Bitwarden app")
    static let lookingForBitwarden = NSLocalizedString("looking.for.bitwarden", value: "Bitwarden not installed…", comment: "Setup of the integration with Bitwarden app")
    static let allowIntegration = NSLocalizedString("allow.integration", value: "Allow Integration with DuckDuckGo", comment: "Setup of the integration with Bitwarden app")
    static let openBitwardenAndLogInOrUnlock = NSLocalizedString("open.bitwarden.and.log.in.or.unlock", value: "Open Bitwarden and Log in or Unlock your vault.", comment: "Setup of the integration with Bitwarden app")
    static let selectBitwardenPreferences = NSLocalizedString("select.bitwarden.preferences", value: "Select Bitwarden → Preferences from the Mac menu bar.", comment: "Setup of the integration with Bitwarden app (up to and including macOS 12)")
    static let selectBitwardenSettings = NSLocalizedString("select.bitwarden.settings", value: "Select Bitwarden → Settings from the Mac menu bar.", comment: "Setup of the integration with Bitwarden app (macOS 13 and above)")
    static let scrollToFindAppSettings = NSLocalizedString("scroll.to.find.app.settings", value: "Scroll to find the App Settings (All Accounts) section.", comment: "Setup of the integration with Bitwarden app")
    static let checkAllowIntegration = NSLocalizedString("check.allow.integration", value: "Check Allow integration with DuckDuckGo.", comment: "Setup of the integration with Bitwarden app")
    static let openBitwarden = NSLocalizedString("open.bitwarden", value: "Open Bitwarden", comment: "Button to open Bitwarden app")
    static let bitwardenIsReadyToConnect = NSLocalizedString("bitwarden.is.ready.to.connect", value: "Bitwarden is ready to connect to DuckDuckGo!", comment: "Setup of the integration with Bitwarden app")
    static let bitwardenWaitingForPermissions = NSLocalizedString("bitwarden.waiting.for.permissions", value: "Waiting for permission to use Bitwarden in DuckDuckGo…", comment: "Setup of the integration with Bitwarden app")
    static let bitwardenIntegrationComplete = NSLocalizedString("bitwarden.integration.complete", value: "Bitwarden integration complete!", comment: "Setup of the integration with Bitwarden app")
    static let bitwardenIntegrationCompleteInfo = NSLocalizedString("bitwarden.integration.complete.info", value: "You are now using Bitwarden as your password manager.", comment: "Setup of the integration with Bitwarden app")

    static let bitwardenCommunicationInfo = NSLocalizedString("bitwarden.connect.communication-info", value: "All communication between Bitwarden and DuckDuckGo is encrypted and the data never leaves your device.", comment: "Warns users that all communication between the DuckDuckGo browser and the password manager Bitwarden is encrypted and doesn't leave the user device")
    static let bitwardenHistoryInfo = NSLocalizedString("bitwarden.connect.history-info", value: "Bitwarden will have access to your browsing history.", comment: "Warn users that the password Manager Bitwarden will have access to their browsing history")

    static let showAIChatShortcut = NSLocalizedString("pinning.show-duckai-shortcut", value: "Show Duck.ai Shortcut", comment: "Menu item for showing the AI Chat shortcut")
    static let hideAIChatShortcut = NSLocalizedString("pinning.hide-duckai-shortcut", value: "Hide Duck.ai Shortcut", comment: "Menu item for hiding the AI Chat shortcut")

    static let showAutofillShortcut = NSLocalizedString("pinning.show-autofill-shortcut", value: "Show Passwords Shortcut", comment: "Menu item for showing the passwords shortcut")
    static let hideAutofillShortcut = NSLocalizedString("pinning.hide-autofill-shortcut", value: "Hide Passwords Shortcut", comment: "Menu item for hiding the passwords shortcut")

    static let showBookmarksShortcut = NSLocalizedString("pinning.show-bookmarks-shortcut", value: "Show Bookmarks Shortcut", comment: "Menu item for showing the bookmarks shortcut")
    static let hideBookmarksShortcut = NSLocalizedString("pinning.hide-bookmarks-shortcut", value: "Hide Bookmarks Shortcut", comment: "Menu item for hiding the bookmarks shortcut")

    static let showDownloadsShortcut = NSLocalizedString("pinning.show-downloads-shortcut", value: "Show Downloads Shortcut", comment: "Menu item for showing the downloads shortcut")
    static let hideDownloadsShortcut = NSLocalizedString("pinning.hide-downloads-shortcut", value: "Hide Downloads Shortcut", comment: "Menu item for hiding the downloads shortcut")

    static let showNetworkProtectionShortcut = NSLocalizedString("pinning.show-netp-shortcut", value: "Show VPN Shortcut", comment: "Menu item for showing the NetP shortcut")
    static let hideNetworkProtectionShortcut = NSLocalizedString("pinning.hide-netp-shortcut", value: "Hide VPN Shortcut", comment: "Menu item for hiding the NetP shortcut")

    // MARK: - Tooltips

    static let autofillShortcutTooltip = NSLocalizedString("tooltip.autofill.shortcut", value: "Autofill", comment: "Tooltip for the autofill shortcut")

    static let homeButtonTooltip = NSLocalizedString("tooltip.home.button", value: "Home", comment: "Tooltip for the home button")

    static let bookmarksShortcutTooltip = NSLocalizedString("tooltip.bookmarks.shortcut", value: "Bookmarks", comment: "Tooltip for the bookmarks shortcut")
    static let downloadsShortcutTooltip = NSLocalizedString("tooltip.downloads.shortcut", value: "Downloads", comment: "Tooltip for the downloads shortcut")

    static let addItemTooltip = NSLocalizedString("tooltip.autofill.add-item", value: "Add item", comment: "Tooltip for the Add Item button")
    static let moreOptionsTooltip = NSLocalizedString("tooltip.autofill.more-options", value: "More options", comment: "Tooltip for the More Options button")

    static let newBookmarkTooltip = NSLocalizedString("tooltip.bookmarks.new-bookmark", value: "New bookmark", comment: "Tooltip for the New Bookmark button")
    static let newFolderTooltip = NSLocalizedString("tooltip.bookmarks.new-folder", value: "New folder", comment: "Tooltip for the New Folder button")
    static let manageBookmarksTooltip = NSLocalizedString("tooltip.bookmarks.manage-bookmarks", value: "Manage bookmarks", comment: "Tooltip for the Manage Bookmarks button")
    static let bookmarksManage = NSLocalizedString("bookmarks.manage", value: "Manage", comment: "Button for opening the bookmarks management interface")
    static let bookmarksSearch = NSLocalizedString("tooltip.bookmarks.search", value: "Search bookmarks", comment: "Tooltip to activate the bookmark search")
    static let bookmarksSort = NSLocalizedString("tooltip.bookmarks.sort", value: "Sort", comment: "Tooltip to activate the bookmark sort")
    static let bookmarksSortByNameTitle = NSLocalizedString("tooltip.bookmarks.sort.name.title", value: "Sort by Name", comment: "Title when bookmark sort by name is enabled")
    static let bookmarksSortManual = NSLocalizedString("bookmarks.sort.manual", value: "Manual", comment: "Button to sort bookmarks by manual")
    static let bookmarksSortByName = NSLocalizedString("bookmarks.sort.name", value: "Name", comment: "Button to sort bookmarks by name ascending")
    static let bookmarksSortByNameAscending = NSLocalizedString("bookmarks.sort.name.asc", value: "Ascending", comment: "Button to sort bookmarks by name ascending")
    static let bookmarksSortByNameDescending = NSLocalizedString("bookmarks.sort.name.desc", value: "Descending", comment: "Button to sort bookmarks by name descending")

    static let bookmarksEmptyStateTitle = NSLocalizedString("bookmarks.empty.state.title", value: "No bookmarks yet", comment: "Title displayed in Bookmark Manager when there is no bookmarks yet")
    static let bookmarksEmptyStateMessage = NSLocalizedString("bookmarks.empty.state.message", value: "If your bookmarks are saved in another browser, you can import them into DuckDuckGo.", comment: "Text displayed in Bookmark Manager when there is no bookmarks yet")

    static let bookmarksEmptySearchResultStateTitle = NSLocalizedString("bookmarks.empty.search.resukt..state.title", value: "No bookmarks found", comment: "Title displayed in Bookmark Panel when there is no bookmarks that match the search query")
    static let bookmarksEmptySearchResultStateMessage = NSLocalizedString("bookmarks.empty.search.result.state.message", value: "Try different search terms.", comment: "Text displayed in Bookmark Panel when there is no bookmarks that match the search query")

    static let openDownloadsFolderTooltip = NSLocalizedString("tooltip.downloads.open-downloads-folder", value: "Open downloads folder", comment: "Tooltip for the Open Downloads Folder button")
    static let clearDownloadHistoryTooltip = NSLocalizedString("tooltip.downloads.clear-download-history", value: "Clear download history", comment: "Tooltip for the Clear Downloads button")

    static let newTabTooltip = NSLocalizedString("tooltip.tab.new-tab", value: "Open a new tab", comment: "Tooltip for the New Tab button")
    static let clearBrowsingHistoryTooltip = NSLocalizedString("tooltip.fire.clear-browsing-history", value: "Clear browsing history", comment: "Tooltip for the Fire button")
    static let navigateBackTooltip = NSLocalizedString("tooltip.navigation.back", value: "Show the previous page\nHold to show history", comment: "Tooltip for the Back button")
    static let navigateForwardTooltip = NSLocalizedString("tooltip.navigation.forward", value: "Show the next page\nHold to show history", comment: "Tooltip for the Forward button")
    static let refreshPageTooltip = NSLocalizedString("tooltip.navigation.refresh", value: "Reload this page", comment: "Tooltip for the Refresh button")
    static let stopLoadingTooltip = NSLocalizedString("tooltip.navigation.stop", value: "Stop loading this page", comment: "Tooltip for the Stop Navigation button")
    static let applicationMenuTooltip = NSLocalizedString("tooltip.application-menu.show", value: "Open application menu", comment: "Tooltip for the Application Menu button")

    static let privacyDashboardTooltip = NSLocalizedString("tooltip.privacy-dashboard.show", value: "Show the Privacy Dashboard and manage site settings", comment: "Tooltip for the Privacy Dashboard button")
    static let addBookmarkTooltip = NSLocalizedString("tooltip.bookmark.add", value: "Bookmark this page", comment: "Tooltip for the Add Bookmark button")
    static let editBookmarkTooltip = NSLocalizedString("tooltip.bookmark.edit", value: "Edit bookmark", comment: "Tooltip for the Edit Bookmark button")

    static let findInPageCloseTooltip = NSLocalizedString("tooltip.find-in-page.close", value: "Close find bar", comment: "Tooltip for the Find In Page bar's Close button")
    static let findInPageNextTooltip = NSLocalizedString("tooltip.find-in-page.next", value: "Next result", comment: "Tooltip for the Find In Page bar's Next button")
    static let findInPagePreviousTooltip = NSLocalizedString("tooltip.find-in-page.previous", value: "Previous result", comment: "Tooltip for the Find In Page bar's Previous button")
    static let findInPageTextFieldPlaceholder = NSLocalizedString("find-in-page.text-field.placeholder", value: "Find in page", comment: "Placeholder text for the text field where the user inputs strings to searcg in the web page")

    static let copyUsernameTooltip = NSLocalizedString("autofill.copy-username", value: "Copy username", comment: "Tooltip for the Autofill panel's Copy Username button")
    static let copyPasswordTooltip = NSLocalizedString("autofill.copy-password", value: "Copy password", comment: "Tooltip for the Autofill panel's Copy Password button")
    static let showPasswordTooltip = NSLocalizedString("autofill.show-password", value: "Show password", comment: "Tooltip for the Autofill panel's Show Password button")
    static let hidePasswordTooltip = NSLocalizedString("autofill.hide-password", value: "Hide password", comment: "Tooltip for the Autofill panel's Hide Password button")

    static let autofillShowCardCvvTooltip = NSLocalizedString("autofill.show-card-cvv", value: "Show CVV", comment: "Tooltip for the Autofill panel's Show CVV button")
    static let autofillHideCardCvvTooltip = NSLocalizedString("autofill.hide-card-cvv", value: "Hide CVV", comment: "Tooltip for the Autofill panel's Hide CVV button")

    static let databaseFactoryFailedMessage = NSLocalizedString("database.factory.failed.message", value: "There was an error initializing the database", comment: "Alert title when we fail to init database")
    static let databaseFactoryFailedInformative = NSLocalizedString("database.factory.failed.information", value: "Restart your Mac and try again", comment: "Info to restart macOS after database init failure")

    static func passwordManagerPopoverTitle(managerName: String) -> String {
        let localized = NSLocalizedString("autofill.popover.password-manager-title", value: "You're using %@ to manage passwords", comment: "Explanation of what password manager is being used")
        return String(format: localized, managerName)
    }
    static let passwordManagerPopoverSettingsButton = NSLocalizedString("autofill.popover.settings-button", value: "Settings", comment: "Open Settings Button")
    static let passwordManagerPopoverChangeInSettingsLabel = NSLocalizedString("autofill.popover.change-in", value: "Change in", comment: "Suffix of the label - change in settings - ")

    static func passwordManagerPopoverConnectedToUser(user: String) -> String {
        let localized = NSLocalizedString("autofill.popover.password-manager-connected-to-user", value: "Connected to user %@", comment: "Label describing what user is connected to the password manager")
        return String(format: localized, user)
    }

    static func passwordManagerAutosavePopoverText(domain: String) -> String {
        let localized = NSLocalizedString("autofill.popover.autosave.text", value: "Password saved for %@", comment: "Text confirming a password has been saved for the %@ domain")
        return String(format: localized, domain)
    }

    static let passwordManagerAutosaveButtonText = NSLocalizedString("autofill.popover.autosave.button.text",
                                                                      value: "View",
                                                                      comment: "Button to view the recently autosaved password")

    static let passwordManagerAutoPinnedPopoverText = NSLocalizedString("autofill.popover.passwords.auto-pinned.text", value: "Shortcut Added!", comment: "Text confirming the password manager has been pinned to the toolbar")

    static let passwordManagerPinnedPromptPopoverText = NSLocalizedString("autofill.popover.passwords.pin-prompt.text",
                                                                          value: "Add passwords shortcut?",
                                                                          comment: "Text prompting user to pin the password manager shortcut to the toolbar")
    static let passwordManagerPinnedPromptPopoverButtonText = NSLocalizedString("autofill.popover.passwords.pin-prompt.button.text",
                                                                     value: "Add Shortcut",
                                                                     comment: "Button to pin the password manager shortcut to the toolbar")

    static func openPasswordManagerButton(managerName: String) -> String {
        let localized = NSLocalizedString("autofill.popover.open-password-manager", value: "Open %@", comment: "Open password manager button")
        return String(format: localized, managerName)
    }

    static let passwordManagerLockedStatus = NSLocalizedString("autofill.manager.status.locked", value: "Locked", comment: "Locked status for password manager")
    static let passwordManagerUnlockedStatus = NSLocalizedString("autofill.manager.status.unlocked", value: "Unlocked", comment: "Unlocked status for password manager")

    static func alertTitle(from domain: String) -> String {
        let localized = NSLocalizedString("alert.title", value: "A message from %@", comment: "Title formatted with presenting domain")
        return String(format: localized, domain)
    }

    static let noAccessToDownloadsFolderHeader = NSLocalizedString("no.access.to.downloads.folder.header", value: "DuckDuckGo needs permission to access your Downloads folder", comment: "Header of the alert dialog warning the user they need to give the browser permission to access the Downloads folder")

    private static let noAccessToDownloadsFolderLegacy = NSLocalizedString("no.access.to.downloads.folder.legacy", value: "Grant access in Security & Privacy preferences in System Settings.", comment: "Alert presented to user if the app doesn't have rights to access Downloads folder. This is used for macOS version 12 and below")
    private static let noAccessToDownloadsFolderModern = NSLocalizedString("no.access.to.downloads.folder.modern", value: "Grant access in Privacy & Security preferences in System Settings.", comment: "Alert presented to user if the app doesn't have rights to access Downloads folder. This is used for macOS version 13 and above")

    static var noAccessToDownloadsFolder: String {
        if #available(macOS 13.0, *) {
            return noAccessToDownloadsFolderModern
        } else {
            return noAccessToDownloadsFolderLegacy
        }
    }

    static let cannotOpenFileAlertHeader = NSLocalizedString("cannot.open.file.alert.header", value: "Cannot Open File", comment: "Header of the alert dialog informing user it is not possible to open the file")
    static let cannotOpenFileAlertInformative = NSLocalizedString("cannot.open.file.alert.informative", value: "The App Store version of DuckDuckGo can only access local files if you drag-and-drop them into a browser window.\n\n To navigate local files using the address bar, please download DuckDuckGo directly from https://duckduckgo.com/mac.", comment: "Informative of the alert dialog informing user it is not possible to open the file")

    // MARK: New Tab
    // Context Menu
    static let newTabBottomPopoverTitle = NSLocalizedString("newTab.bottom.popover.title", value: "New Tab Page", comment: "Title of the popover that appears when pressing the bottom right button")
    static let newTabMenuItemShowSearchBar = NSLocalizedString("newTab.menu.item.show.search.bar", value: "Show Search Box", comment: "Title of the menu item in the home page to show/hide search box (search field)")
    static let newTabMenuItemShowFavorite = NSLocalizedString("newTab.menu.item.show.favorite", value: "Show Favorites", comment: "Title of the menu item in the home page to show/hide favorite section")
    static let newTabMenuItemShowContinuteSetUp = NSLocalizedString("newTab.menu.item.show.continue.setup", value: "Show Next Steps", comment: "Title of the menu item in the home page to show/hide continue setup section")
    static let newTabMenuItemShowRecentActivity = NSLocalizedString("newTab.menu.item.show.recent.activity", value: "Show Recent Activity", comment: "Title of the menu item in the home page to show/hide recent activity section")

    // Search Bar
    static let newTabSearchBarSectionTitle = NSLocalizedString("newTab.search.bar.section.title", value: "Search Box", comment: "Setting to show or hide the search box (search field) in the home page")

    // Favorites
    static let newTabFavoriteSectionTitle = NSLocalizedString("newTab.favorites.section.title", value: "Favorites", comment: "Title of the Favorites section in the home page")

    // Set Up
    static let newTabSetUpSectionTitle = NSLocalizedString("newTab.setup.section.title", value: "Next Steps", comment: "Title of the setup section in the home page")
    static let newTabSetUpDefaultBrowserCardTitle = NSLocalizedString("newTab.setup.default.browser.title", value: "Default to Privacy", comment: "Title of the Default Browser card of the Set Up section in the home page")
    static let newTabSetUpDockCardTitle = NSLocalizedString("newTab.setup.dock.title", value: "Keep in Your Dock", comment: "Title of the new tab page card for adding application to the Dock")
    static let newTabSetUpImportCardTitle = NSLocalizedString("newTab.setup.import.title", value: "Bring Your Stuff", comment: "Title of the Import card of the Set Up section in the home page")
    static let newTabSetUpDuckPlayerCardTitle = NSLocalizedString("newTab.setup.duck.player.title", value: "Clean Up YouTube", comment: "Title of the Duck Player card of the Set Up section in the home page")
    static let newTabSetUpEmailProtectionCardTitle = NSLocalizedString("newTab.setup.email.protection.title", value: "Protect Your Inbox", comment: "Title of the Email Protection card of the Set Up section in the home page")

    static let newTabSetUpDefaultBrowserAction = NSLocalizedString("newTab.setup.default.browser.action", value: "Make Default Browser", comment: "Action title on the action menu of the Default Browser card")
    static let newTabSetUpDockAction = NSLocalizedString("newTab.setup.dock.action", value: "Keep In Dock", comment: "Action title on the action menu of the 'Add App to the Dock' card")
    static let newTabSetUpDockConfirmation = NSLocalizedString("newTab.setup.dock.confirmation", value: "Added to Dock!", comment: "Confirmation title after user clicks on 'Add to Dock' card")
    static let newTabSetUpImportAction = NSLocalizedString("newTab.setup.Import.action", value: "Import Now", comment: "Action title on the action menu of the Import card of the Set Up section in the home page")
    static let newTabSetUpDuckPlayerAction = NSLocalizedString("newTab.setup.duck.player.action", value: "Try Duck Player", comment: "Action title on the action menu of the Duck Player card of the Set Up section in the home page")
    static let newTabSetUpEmailProtectionAction = NSLocalizedString("newTab.setup.email.protection.action", value: "Get a Duck Address", comment: "Action title on the action menu of the Email Protection card of the Set Up section in the home page")
    static let newTabSetUpRemoveItemAction = NSLocalizedString("newTab.setup.remove.item", value: "Dismiss", comment: "Action title on the action menu of the set up cards card of the SetUp section in the home page to remove the item")

    static let newTabSetUpDefaultBrowserSummary = NSLocalizedString("newTab.setup.default.browser.summary", value: "We automatically block trackers as you browse. It's privacy, simplified.", comment: "Summary of the Default Browser card")
    static let newTabSetUpDockSummary = NSLocalizedString("newTab.setup.dock.summary", value: "Get to DuckDuckGo faster by adding it to your Dock.", comment: "Summary of the 'Add App to the Dock' card")
    static let newTabSetUpImportSummary = NSLocalizedString("newTab.setup.import.summary", value: "Import bookmarks, favorites, and passwords from your old browser.", comment: "Summary of the Import card of the Set Up section in the home page")
    static let newTabSetUpDuckPlayerSummary = NSLocalizedString("newTab.setup.duck.player.summary", value: "Enjoy a clean viewing experience without personalized ads.", comment: "Summary of the Duck Player card of the Set Up section in the home page")
    static let newTabSetUpEmailProtectionSummary = NSLocalizedString("newTab.setup.email.protection.summary", value: "Generate custom @duck.com addresses that clean trackers from incoming email.", comment: "Summary of the Email Protection card of the Set Up section in the home page")

    // Recent Activity
    static let newTabRecentActivitySectionTitle = NSLocalizedString("newTab.recent.activity.section.title", value: "Recent Activity", comment: "Title of the RecentActivity section in the home page")
    static let newTabPrivacyStatsSectionTitle = NSLocalizedString("newTab.privacy.stats.section.title", value: "Protection Stats", comment: "Title of the Privacy Stats section in the home page")
    static let justNow = NSLocalizedString("newTab.recent.activity.just.now", value: "Just now", comment: "Relative timestamp for a URL that was last visited within recent 60 seconds")
    static let burnerWindowHeader = NSLocalizedString("burner.window.header", value: "Fire Window", comment: "Header shown on the hompage of the Fire Window")
    static let burnerTabHomeTitle = NSLocalizedString("burner.tab.home.title", value: "New Fire Tab", comment: "Tab title for Fire Tab")
    static let burnerHomepageDescription1 = NSLocalizedString("burner.homepage.description.1", value: "Browse without saving local history", comment: "Descriptions of features Fire page. Provides information about browsing functionalities such as browsing without saving local history, signing in to a site with a different account, and troubleshooting websites.")
    static let burnerHomepageDescription2 = NSLocalizedString("burner.homepage.description.2", value: "Sign in to a site with a different account", comment: "Descriptions of features Fire page. Provides information about browsing functionalities such as browsing without saving local history, signing in to a site with a different account, and troubleshooting websites.")
    static let burnerHomepageDescription3 = NSLocalizedString("burner.homepage.description.3", value: "Troubleshoot websites", comment: "Descriptions of features Fire page. Provides information about browsing functionalities such as browsing without saving local history, signing in to a site with a different account, and troubleshooting websites.")
    static let burnerHomepageDescription4 = NSLocalizedString("burner.homepage.description.4", value: "Fire windows are isolated from other browser data, and their data is burned when you close them. They have the same tracking protection as other windows.", comment: "This describes the functionality of one of out browser feature Fire Window, highlighting their isolation from other browser data and the automatic deletion of their data upon closure. Additionally, it emphasizes that fire windows offer the same level of tracking protection as other browsing windows.")

    // Email Protection Management
    static let disableEmailProtectionTitle = NSLocalizedString("disable.email.protection.title", value: "Disable Email Protection Autofill?", comment: "Title for alert shown when user disables email protection")
    static let disableEmailProtectionMessage = NSLocalizedString("disable.email.protection.mesage", value: "This will only disable Autofill for Duck Addresses in this browser. \n\n You can still manually enter Duck Addresses and continue to receive forwarded email.", comment: "Message for alert shown when user disables email protection")
    static let disable = NSLocalizedString("disable", value: "Disable", comment: "Email protection Disable button text")

    // "data-broker-protection.optionsMenu" - Menu item data broker protection feature
    static let dataBrokerProtectionOptionsMenuItem = "Personal Information Removal"
    // "tab.dbp.title" - Tab data broker protection title
    static let tabDataBrokerProtectionTitle = "Personal Information Removal"

    // Bookmarks bar prompt
    static let bookmarksBarPromptTitle = NSLocalizedString("bookmarks.bar.prompt.title", value: "Show Bookmarks Bar?", comment: "Title for bookmarks bar prompt")
    static let bookmarksBarPromptMessageMarkdown = NSLocalizedString("bookmarks.bar.prompt.message1", value: "Show the Bookmarks Bar for quick access to your favorite bookmarks. You can adjust this later in **Settings** > **Appearance**.", comment: " message with markdown show for bookmarks bar prompt, make sure to keep the ** ** for the translated words Settings and Appearance")
    static let bookmarksBarPromptMessageFallback = NSLocalizedString("bookmarks.bar.prompt.message1", value: "Show the Bookmarks Bar for quick access to your favorite bookmarks. You can adjust this later in Settings > Appearance.", comment: " message show for bookmarks bar prompt")

    static let bookmarksBarPromptDismiss = NSLocalizedString("bookmarks.bar.prompt.dismiss", value: "Hide", comment: "Dismiss button label on bookmarks bar prompt")
    static let bookmarksBarPromptAccept = NSLocalizedString("bookmarks.bar.prompt.accept", value: "Show", comment: "Accept button label on bookmarks bar prompt")

    // MARK: Home Page Settings
    static let homePageSettingsOnboardingTitle = NSLocalizedString("home.page.settings.onboarding.title", value: "New search box, custom backgrounds & more!", comment: "Home Page Settings Onboarding message title")
    static let homePageSettingsOnboardingMessage = NSLocalizedString("home.page.settings.onboarding.message", value: "Add extra personality and pick what you want to see on your new tab page. Give it a try!", comment: "Home Page Settings Onboarding message")
    static let homePageSettingsTitle = NSLocalizedString("home.page.settings.header", value: "Customize", comment: "Home Page Settings title")
    static let goToSettings = NSLocalizedString("home.page.settings.go.to.settings", value: "Go to Settings", comment: "Settings button caption")
    static let background = NSLocalizedString("home.page.settings.background", value: "Background", comment: "Section title in Home Page Settings to customization Home Page background")
    static let solidColors = NSLocalizedString("home.page.settings.solid.colors", value: "Solid Colors", comment: "Button caption for presenting available solid-color Home Page backgrounds")
    static let gradients = NSLocalizedString("home.page.settings.gradients", value: "Gradients", comment: "Button caption for presenting available Home Page background gradients")
    static let myBackgrounds = NSLocalizedString("home.page.settings.my.backgrounds", value: "My Backgrounds", comment: "Button caption for presenting available user-provided Home Page background images")
    static let myBackgroundsDisclaimer = NSLocalizedString("home.page.settings.my.backgrounds.disclaimer", value: "Images are stored on your device so DuckDuckGo can't see or access them.", comment: "Disclaimer explaining privacy of user-provided custom Home Page background images")
    static let addBackground = NSLocalizedString("home.page.settings.add.background", value: "Add Background", comment: "Button caption for adding user-provided Home Page background image")
    static let defaultBackground = NSLocalizedString("home.page.settings.default.background", value: "Default", comment: "Default as in 'default background'")
    static let browserTheme = NSLocalizedString("home.page.settings.browser.theme", value: "Browser Theme", comment: "Section title in Home Page Settings to adjust browser theme")
    static let homePageSections = NSLocalizedString("home.page.settings.sections", value: "Sections", comment: "Section title in Home Page Settings to adjust Home Page sections visibility")
    static let deleteBackground = NSLocalizedString("home.page.settings.delete.background", value: "Delete Background", comment: "Context menu option to delete custom home page background image")
    static let cannotReadImageAlertMessage = NSLocalizedString("cannot.read.image.alert.message", value: "There was an issue uploading this file", comment: "Header of the alert dialog informing user that the app failed to load the provided custom background image")

    // MARK: Fireproof
    static let fireproofRemoveAllButton = NSLocalizedString("fireproof.domains.remove.all", value: "Remove All", comment: "Label of a button that allows the user to remove all the websites from the fireproofed list")
    static let fireproofSites = NSLocalizedString("fireproof.sites", value: "Fireproof Sites", comment: "Fireproof sites list title")
    static let fireproofCheckboxTitle = NSLocalizedString("fireproof.checkbox.title", value: "Ask to Fireproof websites when signing in", comment: "Fireproof settings checkbox title")
    static let fireproofExplanation = NSLocalizedString("fireproof.explanation", value: "When you Fireproof a site, cookies won't be erased and you'll stay signed in, even after using the Fire Button.", comment: "Fireproofing mechanism explanation")
    static let manageFireproofSites = NSLocalizedString("fireproof.manage-sites", value: "Manage Fireproof Sites…", comment: "Fireproof settings button caption")
    static let autoClear = NSLocalizedString("auto.clear", value: "Auto-Clear", comment: "Header of a section in Settings. The setting configures clearing data automatically after quitting the app.")
    static let automaticallyClearData = NSLocalizedString("automatically.clear.data", value: "Automatically clear tabs and browsing data when DuckDuckGo quits", comment: "Label after the checkbox in Settings which configures clearing data automatically after quitting the app.")
    static let warnBeforeQuit = NSLocalizedString("warn.before.quit", value: "Warn me that tabs and data will be cleared when quitting", comment: "Label after the checkbox in Settings which configures a warning before clearing data on the application termination.")
    static let warnBeforeQuitDialogHeader = NSLocalizedString("warn.before.quit.dialog.header", value: "Clear tabs and browsing data and quit DuckDuckGo?", comment: "A header of warning before clearing data on the application termination.")
    static let warnBeforeQuitDialogCheckboxMessage = NSLocalizedString("warn.before.quit.dialog.checkbox.message", value: "Warn me every time", comment: "A label after checkbox to configure the warning before clearing data on the application termination.")
    static let disableAutoClearToEnableSessionRestore = NSLocalizedString("disable.auto.clear.to.enable.session.restore",
                                                                          value: "Disable auto-clear on quit to turn on session restore.",
                                                                          comment: "Information label in Settings. It tells user that to enable session restoration setting they have to disable burn on quit. Auto-Clear should match the string with 'auto.clear' key")
    static let showDataClearingSettings = NSLocalizedString("show.data.clearing.settings",
                                                            value: "Open Data Clearing Settings",
                                                            comment: "Button in Settings. It navigates user to Data Clearing Settings. The Data Clearing string should match the string with the preferences.data-clearing key")

    // MARK: Crash Report
    static let crashReportTitle = NSLocalizedString("crash-report.title", value: "DuckDuckGo Privacy Browser quit unexpectedly.", comment: "Title of the dialog where the user can send a crash report")
    static let crashReportDescription = NSLocalizedString("crash-report.description", value: "Click “Send to DuckDuckGo“ to submit report to DuckDuckGo. Crash reports help DuckDuckGo diagnose issues and improve our products. No personal information is sent with this report.", comment: "Description of the dialog where the user can send a crash report")
    static let crashReportTextFieldTitle = NSLocalizedString("crash-report.textfield.title", value: "Problem Details", comment: "Title of the text field where the problems that caused the crashed are detailed")
    static let crashReportSendButton = NSLocalizedString("crash-report.send-button", value: "Send to DuckDuckGo", comment: "Button the user can press to send the crash report to DuckDuckGo")
    static let crashReportDontSendButton = NSLocalizedString("crash-report.dont-send-button", value: "Don’t Send", comment: "Button the user can press to not send the crash report")

    // MARK: Downloads
    static let downloadsDialogTitle = NSLocalizedString("downloads.dialog.title", value: "Downloads", comment: "Title of the dialog that manages the Downloads in the browser")
    static let downloadsOpenItem = NSLocalizedString("downloads.open.item", value: "Open", comment: "Contextual menu item in downloads manager to open the downloaded file")
    static let downloadsShowInFinderItem = NSLocalizedString("downloads.show-in-finder.item", value: "Show in Finder", comment: "Contextual menu item in downloads manager to show the downloaded file in Finder")
    static let downloadsCopyLinkItem = NSLocalizedString("downloads.copy-link.item", value: "Copy Download Link", comment: "Contextual menu item in downloads manager to copy the downloaded link")
    static let downloadsOpenWebsiteItem = NSLocalizedString("downloads.open-website.item", value: "Open Originating Website", comment: "Contextual menu item in downloads manager to open the downloaded file originating website")
    static let downloadsRemoveFromListItem = NSLocalizedString("downloads.remove-from-list.item", value: "Remove from List", comment: "Contextual menu item in downloads manager to remove the given downloaded from the list of downloaded files")
    static let downloadsStopItem = NSLocalizedString("downloads.stop.item", value: "Stop", comment: "Contextual menu item in downloads manager to stop the download")
    static let downloadsRestartItem = restartDownloadToolTip
    static let downloadsClearAllItem = NSLocalizedString("downloads.clear-all.item", value: "Clear All", comment: "Contextual menu item in downloads manager to clear all downloaded items from the list")
    static let downloadsNoRecentDownload = NSLocalizedString("downloads.no-recent-downloads", value: "No recent downloads", comment: "Label in the downloads manager that shows that there are no recently downloaded items")
    static let downloadsOpenDownloadsFolder = NSLocalizedString("downloads.open-downloads-folder", value: "Open Downloads Folder", comment: "Button in the downloads manager that allows the user to open the downloads folder")

    // MARK: Updates
    static let updateAvailableMenuItem = NSLocalizedString("update.available.menu.item", value: "Update Available - Install Now", comment: "Title of the menu item that informs user that a new update is available. Clicking on the menu item installs the update")
    static let releaseNotesMenuItem = NSLocalizedString("release.notes.menu.item", value: "Release Notes", comment: "Title of the dialog menu item that opens release notes")
    static let whatsNewMenuItem = NSLocalizedString("whats.new.menu.item", value: "What's New", comment: "Title of the dialog menu item that opens the 'What's New' page")
    static let browserUpdatesTitle = NSLocalizedString("settings.browser.updates.title", value: "Browser Updates", comment: "Title of the section in Settings where people set up automatic vs manual updates")
    static let automaticUpdates = NSLocalizedString("settings.automatic.updates", value: "Automatically install updates (recommended)", comment: "Title of the checkbox item to set up automatic updates of the browser")
    static let manualUpdates = NSLocalizedString("settings.manual.updates", value: "Check for updates but let you choose to install them", comment: "Title of the checkbox item to set up manual updates of the browser")
    static let checkingForUpdate = NSLocalizedString("settings.checking.for.update", value: "Checking for update", comment: "Label informing users the app is currently checking for new update")
    static let downloadingUpdate = NSLocalizedString("settings.downloading.update", value: "Downloading update %@", comment: "Label informing users the app is currently downloading the update. This will contain a percentage")
    static let preparingUpdate = NSLocalizedString("settings.preparing.update", value: "Preparing update", comment: "Label informing users the app is preparing to update.")
    static let updateFailed = NSLocalizedString("settings.update.failed", value: "Update failed", comment: "Label informing users the app is unable to update.")
    static let upToDate = NSLocalizedString("settings.up.to.date", value: "DuckDuckGo is up to date", comment: "Label informing users the app is currently up to date and no update is required.")
    static let newerVersionAvailable = NSLocalizedString("settings.newer.version.available", value: "Newer version available", comment: "Label informing users the newer version of the app is available to install.")
    static let newerCriticalUpdateAvailable = NSLocalizedString("settings.newer.critical.update.available", value: "Critical update needed", comment: "Label informing users the critical update of the app is available to install.")
    static let lastChecked = NSLocalizedString("settings.last.checked", value: "Last checked", comment: "Label informing users what is the last time the app checked for the update.")
    static let restartToUpdate = NSLocalizedString("settings.restart.to.update", value: "Restart To Update", comment: "Button label triggering restart and update of the application.")
    static let runUpdate = NSLocalizedString("settings.run.update", value: "Update DuckDuckGo", comment: "Button label triggering update of the application.")
    static let retryUpdate = NSLocalizedString("settings.retry.update", value: "Retry Update", comment: "Button label triggering a retry of the update.")
    static let browserUpdatedNotification = NSLocalizedString("notification.browser.updated", value: "Browser Updated", comment: "Notification informing user the app has been updated")
    static let browserDowngradedNotification = NSLocalizedString("notification.browser.downgraded", value: "Browser Downgraded", comment: "Notification informing user the app has been downgraded")
    static let criticalUpdateNotification = NSLocalizedString("notification.critical.update", value: "Critical update needed.", comment: "Notification informing user a critical update is available.")
    static let updateAvailableNotification = NSLocalizedString("notification.update.available", value: "New version available.", comment: "Notification informing user the a version of app is available.")
    static let autoUpdateAction = NSLocalizedString("notification.auto.update.action", value: "Restart to update.", comment: "Action to take when an automatic update is available.")
    static let manualUpdateAction = NSLocalizedString("notification.manual.update.action", value: "Click here to update.", comment: "Action to take when a manual update is available.")
    static let viewDetails = NSLocalizedString("view.details.button", value: "View Details", comment: "Button title to open more details about the update")

    enum Bookmarks {
        enum Dialog {
            enum Title {
                static let addBookmark = NSLocalizedString("bookmarks.dialog.title.add", value: "Add Bookmark", comment: "Bookmark creation dialog title")
                static let addedBookmark = NSLocalizedString("bookmarks.dialog.title.added", value: "Bookmark Added", comment: "Bookmark added popover title")
                static let editBookmark = NSLocalizedString("bookmarks.dialog.title.edit", value: "Edit Bookmark", comment: "Bookmark edit dialog title")
                static let addFolder = NSLocalizedString("bookmarks.dialog.folder.title.add", value: "Add Folder", comment: "Bookmark folder creation dialog title")
                static let editFolder = NSLocalizedString("bookmarks.dialog.folder.title.edit", value: "Edit Folder", comment: "Bookmark folder edit dialog title")
                static let bookmarkOpenTabs = NSLocalizedString("bookmarks.dialog.allTabs.title.add", value: "Bookmark Open Tabs (%d)", comment: "Title of dialog to bookmark all open tabs. E.g. 'Bookmark Open Tabs (42)'")
            }
            enum Message {
                static let bookmarkOpenTabsEducational = NSLocalizedString("bookmarks.dialog.allTabs.message.add", value: "These bookmarks will be saved in a new folder:", comment: "Bookmark creation for all open tabs dialog title")
            }
            enum Field {
                static let name = NSLocalizedString("bookmarks.dialog.field.name", value: "Name", comment: "Name field label for Bookmark or Folder")
                static let url = NSLocalizedString("bookmarks.dialog.field.url", value: "URL", comment: "URL field label for Bookmar")
                static let location = NSLocalizedString("bookmarks.dialog.field.location", value: "Location", comment: "Location field label for Bookmark folder")
                static let folderName = NSLocalizedString("bookmarks.dialog.field.folderName", value: "Folder Name", comment: "Folder name field label for Bookmarks folder")
            }
            enum Value {
                static let folderName = NSLocalizedString("bookmarks.dialog.field.folderName.value", value: "%@ - Tabs (%d)", comment: "The suggested name of the folder that will contain the bookmark tabs. Eg. 2024-02-12 - Tabs (42)")
            }
            enum Action {
                static let addBookmark = NSLocalizedString("bookmarks.dialog.action.addBookmark", value: "Add Bookmark", comment: "CTA title for adding a Bookmark")
                static let addFolder = NSLocalizedString("bookmarks.dialog.action.addFolder", value: "Add Folder", comment: "CTA title for adding a Folder")
                static let addAllBookmarks = NSLocalizedString("bookmarks.dialog.action.addAllBookmarks", value: "Save Bookmarks", comment: "CTA title for saving multiple Bookmarks at once")
            }
        }
    }

    // MARK: - Onboarding
    enum ContextualOnboarding {
        static let onboardingTryASearchTitle = NSLocalizedString("contextual.onboarding.try-a-search.title", value: "Try a search!", comment: "Title of a popover on the browser that invites the user to try a search")
        static let onboardingTryASearchMessage = NSLocalizedString("contextual.onboarding.try-a-search.message", value: "Your DuckDuckGo searches are always private.", comment: "Message of a popover on the browser that invites the user to try a search explaining that their searches are anonymous")
        static let onboardingTryASiteTitle = NSLocalizedString("contextual.onboarding.try-a-site.title", value: "Next, try visiting a site!", comment: "Title of a popover on the browser that invites the user to try a visiting a website")
        static let onboardingTryASiteNTPTitle = NSLocalizedString("contextual.onboarding.ntp.try-a-site.title", value: "Try visiting a site!", comment: "Title of a popover on the new tab page browser that invites the user to try a visiting a website")
        static let onboardingTryASiteMessage = NSLocalizedString("contextual.onboarding.try-a-site.message", value: "I’ll block trackers so they can’t spy on you.", comment: "Message of a popover on the browser that invites the user to try visiting a website to explain that we block trackers")
        static let onboardingTryFireButtonTitle = NSLocalizedString("contextual.onboarding.try-fire-button.title", value: "Instantly clear your browsing activity with the *Fire Button*.\n\n%1$@", comment: "Message of a popover on the browser that invites the user to try visiting the browser Fire Button, the parameter is another string (do not remove * and \n\n%1$@")
        static let onboardingTryFireButtonMessage = NSLocalizedString("contextual.onboarding.try-fire-button.message", value: "Give it a try! 🔥", comment: "Message of a popover on the browser that invites the user to try visiting the browser Fire Button.")
        static let onboardingTryFireButtonButton = NSLocalizedString("contextual.onboarding.try-fire-button.button", value: "Try it", comment: "Button on the browser that invites the user to try the Fire Button.")
        static let onboardingGotItButton = NSLocalizedString("contextual.onboarding.got-it.button", value: "Got it", comment: "During onboarding steps this button is shown and takes either to the next steps or closes the onboarding.")
        static let onboardingFirstSearchDoneTitle = NSLocalizedString("contextual.onboarding.first-search-done.title", value: "That’s DuckDuckGo Search!", comment: "After the user performs their first search using the browser, this dialog explains the advantages of using DuckDuckGo")
        static let onboardingFirstSearchDoneMessage = NSLocalizedString("contextual.onboarding.first-search-done.message", value: "Private. Fast. Fewer ads.", comment: "After the user performs their first search using the browser, this dialog explains the advantages of using DuckDuckGo")
        static let onboardingFinalScreenTitle = NSLocalizedString("contextual.onboarding.final-screen.title", value: "You’ve got this!", comment: "Title of the last screen of the onboarding to the browser app")
        static let onboardingFinalScreenMessage = NSLocalizedString("contextual.onboarding.final-screen.message", value: "Remember: every time you browse with me a creepy ad loses its wings.", comment: "Message of the last screen of the onboarding to the browser app.")
        static let onboardingFinalScreenButton = NSLocalizedString("contextual.onboarding.final-screen.button", value: "High five!", comment: "Button on the last screen of the onboarding, it will dismiss the onboarding screen.")
        static let tryASearchOption1English = NSLocalizedString("contextual.onboarding.try-search.option1-English", value: "how to say “duck” in spanish", comment: "Browser Search query for how to say duck in english")
        static let tryASearchOption1International = NSLocalizedString("contextual.onboarding.try-search.option1international", value: "how to say “duck” in english", comment: "Browser Search query for how to say duck in english")
        static let tryASearchOption2English = NSLocalizedString("contextual.onboarding.try-search.option2-english", value: "mighty ducks cast", comment: "Search query for the cast of Mighty Ducks")
        static let tryASearchOption2International = NSLocalizedString("contextual.onboarding.try-search.option2-international", value: "cast of avatar", comment: "Search query for the cast of Avatar")
        static let tryASearchOption3 = NSLocalizedString("contextual.onboarding.try-search.option3", value: "local weather", comment: "Browser Search query for local weather")
        static let tryASearchOptionSurpriseMeTitle = NSLocalizedString("contextual.onboarding.try-search.surprise-me-title", value: "Surprise me!", comment: "Title for a button that triggers an unknown search query for the user.")
        static let tryASearchOptionSurpriseMe = NSLocalizedString("contextual.onboarding.try-search.surprise-me", value: "baby ducklings", comment: "Browser Search query for baby ducklings")
        public static let daxDialogBrowsingSiteIsMajorTracker = NSLocalizedString("dax.onboarding.browsing.site.is.major.tracker", value: "Heads up! I can’t stop %1$@ from seeing your activity on %2$@.\n\nBut browse with me, and I can reduce what %1$@ knows about you overall by blocking their trackers on lots of other sites.",  comment: "First parameter is a string - network name, 2nd parameter is a string - domain name")
        public static let daxDialogBrowsingSiteOwnedByMajorTracker = NSLocalizedString("dax.onboarding.browsing.site.owned.by.major.tracker", value: "Heads up! Since %2$@ owns %1$@, I can’t stop them from seeing your activity here.\n\nBut browse with me, and I can reduce what %2$@ knows about you overall by blocking their trackers on lots of other sites.", comment: "Parameters are domain names (strings)")
        static let daxDialogBrowsingWithOneTracker = NSLocalizedString("contextual.onboarding.browsing.one.tracker", value: "*%1$@* was trying to track you here. I blocked them!\n\n%2$@", comment: "Parameter is domain name (string) and a string do (do not remove \n\n%2$@)")
        static let daxDialogBrowsingWithTwoTrackers = NSLocalizedString("contextual.onboarding.browsing.two.trackers", value: "*%1$@ and %2$@* were trying to track you here. I blocked them!\n\n%3$@", comment: "Parameters are names of the tracker networks (strings) the last is a string (Do not remove \n\n%3$@")
        static let daxDialogBrowsingWithMultipleTrackers = NSLocalizedString("contextual.onboarding.browsing.multiple.trackers", value: "*%2$@, %3$@* and others (%d) were trying to track you here. I blocked them!\n\n%4$@", comment: "First parameter is a count of additional trackers, second and third are names of the tracker networks (strings) the last is a string (Do not remove \n\n%4$@)")
        public static let daxDialogBrowsingWithoutTrackers = NSLocalizedString("dax.onboarding.browsing.without.trackers", value: "As you tap and scroll, I’ll block pesky trackers.\n\nGo ahead - keep browsing!", comment: "")
        static let daxDialogTapTheShield = NSLocalizedString("contextual.onboarding.browsing.trackers.tap.shield", value: "☝️ Tap the shield for more info.", comment: "Suggests to tap to a shield shaped icon that is above the copy")
    }

    enum BrokenSitePrompt {
        static let title = NSLocalizedString("site.not.working.title", value: "Site not working?", comment: "Title that appears on a dialog asking users about possible breakage of a site")
        static let buttonTitle = NSLocalizedString("site.not.working.button.title", value: "Let Us Know", comment: "Button title that appears on a dialog asking users about possible breakage of a site")
    }

    // MARK: - Privacy Pro

    // Key: "subscription.menu.item"
    // Comment: "Title for Subscription item in the options menu"
    static let subscriptionOptionsMenuItem = "Privacy Pro"

    static let identityTheftRestorationOptionsMenuItem = "Identity Theft Restoration"

    static let subscriptionSettingsOptionsMenuItem = NSLocalizedString("subscription.settings.menu.item", value:"Subscription Settings", comment: "Title for Subscription Settings item in the options menu")

    // Key: "preferences.subscription"
    // Comment: "Show subscription preferences"
    static let subscription = "Privacy Pro"

    static let purchasingSubscriptionTitle = NSLocalizedString("subscription.progress.view.purchasing.subscription", value:"Purchase in progress...", comment: "Progress view title when starting the purchase")
    static let restoringSubscriptionTitle = NSLocalizedString("subscription.progress.view.restoring.subscription", value:"Restoring subscription...", comment: "Progress view title when restoring past subscription purchase")
    static let completingPurchaseTitle = NSLocalizedString("subscription.progress.view.completing.purchase", value:"Completing purchase...", comment: "Progress view title when completing the purchase")

    // Mark: Sync Promo
    static let syncPromoBookmarksTitle = NSLocalizedString("sync.promo.bookmarks.title", value:"Sync & Back Up Your Bookmarks", comment: "Title for the Sync Promotion banner")
    static let syncPromoPasswordsTitle = NSLocalizedString("sync.promo.passwords.title", value:"Sync & Back Up Your Passwords  ", comment: "Title for the Sync Promotion banner")
    static let syncPromoBookmarksMessage = NSLocalizedString("sync.promo.bookmarks.message", value:"No account needed. End-to-end encryption means nobody but you can see your bookmarks, not even us.", comment: "Message for the Sync Promotion banner when user has bookmarks that can be synced")
    static let syncPromoPasswordsMessage = NSLocalizedString("sync.promo.passwords.message", value:"No account needed. End-to-end encryption means nobody but you can see your passwords, not even us.", comment: "Message for the Sync Promotion banner when user has passwords that can be synced")
    static let syncPromoConfirmAction = NSLocalizedString("sync.promo.confirm.action", value:"Set Up Sync", comment: "Title for a button in the Sync Promotion banner to set up Sync")
    static let syncPromoDismissAction = NSLocalizedString("sync.promo.dismiss.action", value:"No Thanks", comment: "Title for a button in the Sync Promotion banner to dismiss Sync promotion banner")
    static let syncPromoSidePanelTitle = NSLocalizedString("sync.promo.passwords.side.panel.title", value:"Setup", comment: "Title for the Sync Promotion in passwords side panel")
    static let syncPromoSidePanelSubtitle = NSLocalizedString("sync.promo.passwords.side.panel.subtitle", value:"Sync & Backup", comment: "Subtitle for the Sync Promotion in passwords side panel")

    // Key: "freemium.pir.menu.item"
    // Comment: "Title for Freemium Personal Information Removal (Scan-Only) item in the options menu"
    static let freemiumDBPOptionsMenuItem = "Free Personal Information Scan"

    // Key: "home.page.promotion.freemium.dbp.title"
    // Comment: "Title for the Freemium DBP Home Page Promotion"
    static let homePagePromotionFreemiumDBPTitle = "Personal Information Removal"

    // Key: "home.page.promotion.freemium.dbp.description.markdown"
    // Comment: "Markdown Description for the Freemium DBP Home Page Promotion"
    static let homePagePromotionFreemiumDBPDescriptionMarkdown = "Find out which sites are selling **your info.**"

    // Key: "home.page.promotion.freemium.dbp.description"
    // Comment: "Description for the Freemium DBP Home Page Promotion"
    static let homePagePromotionFreemiumDBPDescription = "Find out which sites are selling your info."

    // Key: "home.page.promotion.freemium.dbp.button.title"
    // Comment: "Title for the Freemium DBP Home Page Promotion Button"
    static let homePagePromotionFreemiumDBPButtonTitle = "Free Scan"

    // Key: "home.page.promotion.freemium.dbp.post.scan.engagement.result.single.match.description"
    // Comment: "Description for the Freemium DBP Home Page Post Scan Engagement Promotion When Only One Record is Found"
    static let homePagePromotionFreemiumDBPPostScanEngagementResultSingleMatchDescription = "Your free personal info scan found 1 record about you on 1 site."

    /// Generates Description for the Freemium DBP Home Page Post Scan Engagement Promotion when records are found on a single broker site.
    /// Key: "home.page.promotion.freemium.dbp.post.scan.engagement.result.single.broker.description"
    ///
    /// - Parameter resultCount: The number of records found.
    /// - Returns: A formatted string indicating the number of records found on 1 site.
    static func homePagePromotionFreemiumDBPPostScanEngagementResultSingleBrokerDescription(resultCount: Int) -> String {
        String(format: "Your free personal info scan found %d records about you on 1 site.", resultCount)
    }

    /// Generates Description for the Freemium DBP Home Page Post Scan Engagement Promotion when records are found on multiple broker sites.
    /// Key: "home.page.promotion.freemium.dbp.post.scan.engagement.result.plural.description"
    ///
    /// - Parameters:
    ///   - resultCount: The number of records found.
    ///   - brokerCount: The number of broker sites where records were found.
    /// - Returns: A formatted string indicating the number of records found on multiple sites.
    static func homePagePromotionFreemiumDBPPostScanEngagementResultPluralDescription(resultCount: Int, brokerCount: Int) -> String {
        String(format: "Your free personal info scan found %d records about you on %d different sites.", resultCount, brokerCount)
    }

    // Key: "home.page.promotion.freemium.dbp.post.scan.engagement.no.results.description"
    // Comment: "Description for the Freemium DBP Home Page Post Scan Engagement Promotion When There Are No Results"
    static let homePagePromotionFreemiumDBPPostScanEngagementNoResultsDescription = "Good news, your free personal info scan didn't find any records about you. We'll keep checking periodically."

    // Key: "home.page.promotion.freemium.dbp.post.scan.engagement.button.title"
    // Comment: "Title for the Freemium DBP Home Page Post Scan Engagement Promotion Button"
    static let homePagePromotionFreemiumDBPPostScanEngagementButtonTitle = "View Results"

    static let removeSuggestionTooltip = NSLocalizedString("remove.suggestion.tooltip", value: "Remove from browsing history", comment: "Tooltip for the button which removes the history entry from the history")

    static let switchToTab = NSLocalizedString("switch.to.tab", value: "Switch to Tab", comment: "Suggestion to switch to an open tab button title")
}
