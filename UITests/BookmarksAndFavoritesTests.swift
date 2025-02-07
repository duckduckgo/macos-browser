//
//  BookmarksAndFavoritesTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import XCTest

class BookmarksAndFavoritesTests: UITestCase {
    private var app: XCUIApplication!
    private var pageTitle: String!
    private var urlForBookmarksBar: URL!
    private let titleStringLength = 12

    private var addressBarBookmarkButton: XCUIElement!
    private var addressBarTextField: XCUIElement!
    private var bookmarkDialogBookmarkFolderDropdown: XCUIElement!
    private var bookmarkPageContextMenuItem: XCUIElement!
    private var bookmarkPageMenuItem: XCUIElement!
    private var bookmarksBarCollectionView: XCUIElement!
    private var bookmarksDialogAddToFavoritesCheckbox: XCUIElement!
    private var bookmarksManagementAccessoryImageView: XCUIElement!
    private var bookmarksMenu: XCUIElement!
    private var bookmarksTabPopup: XCUIElement!
    private var bookmarkTableCellViewFavIconImageView: XCUIElement!
    private var bookmarkTableCellViewMenuButton: XCUIElement!
    private var contextualMenuAddBookmarkToFavoritesMenuItem: XCUIElement!
    private var contextualMenuDeleteBookmarkMenuItem: XCUIElement!
    private var contextualMenuRemoveBookmarkFromFavoritesMenuItem: XCUIElement!
    private var defaultBookmarkDialogButton: XCUIElement!
    private var defaultBookmarkOtherButton: XCUIElement!
    private var favoriteGridAddFavoriteButton: XCUIElement!
    private var favoriteThisPageMenuItem: XCUIElement!
    private var manageBookmarksMenuItem: XCUIElement!
    private var openBookmarksMenuItem: XCUIElement!
    private var optionsButton: XCUIElement!
    private var removeFavoritesContextMenuItem: XCUIElement!
    private var resetBookMarksMenuItem: XCUIElement!
    private var settingsAppearanceButton: XCUIElement!
    private var showBookmarksBarPreferenceToggle: XCUIElement!
    private var showBookmarksBarAlways: XCUIElement!
    private var showBookmarksBarPopup: XCUIElement!
    private var showFavoritesPreferenceToggle: XCUIElement!

    override class func setUp() {
        super.setUp()
        UITests.firstRun()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        pageTitle = UITests.randomPageTitle(length: titleStringLength)
        urlForBookmarksBar = UITests.simpleServedPage(titled: pageTitle)
        addressBarBookmarkButton = app.buttons["AddressBarButtonsViewController.bookmarkButton"]
        addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        bookmarkDialogBookmarkFolderDropdown = app.popUpButtons["bookmark.add.folder.dropdown"]
        bookmarkPageContextMenuItem = app.menuItems["ContextMenuManager.bookmarkPageMenuItem"]
        bookmarkPageMenuItem = app.menuItems["MoreOptionsMenu.bookmarkPage"]
        bookmarksBarCollectionView = app.collectionViews["BookmarksBarViewController.bookmarksBarCollectionView"]
        bookmarksDialogAddToFavoritesCheckbox = app.checkBoxes["bookmark.add.add.to.favorites.button"]
        bookmarksManagementAccessoryImageView = app.images["BookmarkTableCellView.accessoryImageView"]
        bookmarksMenu = app.menuBarItems["Bookmarks"]
        bookmarksTabPopup = app.popUpButtons["Bookmarks"]
        bookmarkTableCellViewFavIconImageView = app.images["BookmarkTableCellView.favIconImageView"]
        bookmarkTableCellViewMenuButton = app.buttons["BookmarkTableCellView.menuButton"]
        contextualMenuAddBookmarkToFavoritesMenuItem = app.menuItems["ContextualMenu.addBookmarkToFavoritesMenuItem"]
        contextualMenuDeleteBookmarkMenuItem = app.menuItems["ContextualMenu.deleteBookmark"]
        contextualMenuRemoveBookmarkFromFavoritesMenuItem = app.menuItems["ContextualMenu.removeBookmarkFromFavoritesMenuItem"]
        defaultBookmarkDialogButton = app.buttons["BookmarkDialogButtonsView.defaultButton"]
        defaultBookmarkOtherButton = app.buttons["BookmarkDialogButtonsView.otherButton"]
        favoriteGridAddFavoriteButton = app.buttons["Add Favorite"]
        favoriteThisPageMenuItem = app.menuItems["MainMenu.favoriteThisPage"]
        manageBookmarksMenuItem = app.menuItems["MainMenu.manageBookmarksMenuItem"]
        openBookmarksMenuItem = app.menuItems["MoreOptionsMenu.openBookmarks"]
        optionsButton = app.buttons["NavigationBarViewController.optionsButton"]
        removeFavoritesContextMenuItem = app.menuItems["HomePage.Views.removeFavorite"]
        resetBookMarksMenuItem = app.menuItems["MainMenu.resetBookmarks"]
        settingsAppearanceButton = app.buttons["PreferencesSidebar.appearanceButton"]
        showBookmarksBarAlways = app.menuItems["Preferences.AppearanceView.showBookmarksBarAlways"]
        showBookmarksBarPopup = app.popUpButtons["Preferences.AppearanceView.showBookmarksBarPopUp"]
        showBookmarksBarPreferenceToggle = app.checkBoxes["Preferences.AppearanceView.showBookmarksBarPreferenceToggle"]
        showFavoritesPreferenceToggle = app.checkBoxes["Preferences.AppearanceView.showFavoritesToggle"]

        app.launch()
        resetBookmarks()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Let's enforce a single window
        app.typeKey("n", modifierFlags: .command)
    }

    func test_bookmarks_canBeAddedTo_withContextClickBookmarkThisPage() {
        openSiteToBookmark(bookmarkingViaDialog: false, escapingDialog: false)
        app.windows.webViews[pageTitle].rightClick()
        bookmarkPageContextMenuItem.clickAfterExistenceTestSucceeds()
        XCTAssertTrue( // Check Add Bookmark dialog for existence but don't click on it
            defaultBookmarkDialogButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog option button didn't appear with the expected title in a reasonable timeframe."
        )
        XCTAssertTrue(
            addressBarBookmarkButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar bookmark button didn't appear with the expected title in a reasonable timeframe."
        )
        XCTAssertTrue(
            bookmarkDialogBookmarkFolderDropdown.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog's bookmark folder dropdown didn't appear with the expected title in a reasonable timeframe."
        )
        let bookmarkDialogBookmarkFolderDropdownValue = try? XCTUnwrap( // Bookmark dialog must default to "Bookmarks" folder
            bookmarkDialogBookmarkFolderDropdown.value as? String,
            "It wasn't possible to get the value of the \"Add bookmark\" dialog's bookmark folder dropdown as String"
        )
        XCTAssertEqual(
            bookmarkDialogBookmarkFolderDropdownValue,
            "Bookmarks",
            "The accessibility value of the \"Add bookmark\" dialog's bookmark folder dropdown must be \"Bookmarks\"."
        )
        let addressBarBookmarkButtonValue = try? XCTUnwrap(
            addressBarBookmarkButton.value as? String,
            "It wasn't possible to get the value of the address bar bookmark button as String"
        )

        XCTAssertEqual( // The bookmark icon is already in a filled state and it isn't necessary to click the add button
            addressBarBookmarkButtonValue,
            "Bookmarked",
            "The accessibility value of the address bar bookmark button must be \"Bookmarked\", which indicates the icon in the filled state."
        )

        bookmarksMenu.clickAfterExistenceTestSucceeds()
        XCTAssertTrue( // And the bookmark is found in the Bookmarks menu
            app.menuItems[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmark in the \"Bookmarks\" menu with the title of the test page didn't appear with the expected title in a reasonable timeframe."
        )
    }

    func test_bookmarks_canBeAddedTo_withSettingsItemBookmarkThisPage() {
        openSiteToBookmark(bookmarkingViaDialog: false, escapingDialog: false)
        optionsButton.clickAfterExistenceTestSucceeds()
        openBookmarksMenuItem.hoverAfterExistenceTestSucceeds()
        bookmarkPageMenuItem.clickAfterExistenceTestSucceeds()
        XCTAssertTrue( // Check Add Bookmark dialog for existence but don't click on it
            defaultBookmarkDialogButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog option button didn't appear with the expected title in a reasonable timeframe."
        )
        XCTAssertTrue(
            addressBarBookmarkButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar bookmark button didn't appear with the expected title in a reasonable timeframe."
        )
        XCTAssertTrue(
            bookmarkDialogBookmarkFolderDropdown.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog's bookmark folder dropdown didn't appear with the expected title in a reasonable timeframe."
        )
        let bookmarkDialogBookmarkFolderDropdownValue = try? XCTUnwrap(
            bookmarkDialogBookmarkFolderDropdown.value as? String,
            "It wasn't possible to get the value of the \"Add bookmark\" dialog's bookmark folder dropdown as String"
        )
        XCTAssertEqual( // Bookmark dialog must default to "Bookmarks" folder
            bookmarkDialogBookmarkFolderDropdownValue,
            "Bookmarks",
            "The accessibility value of the \"Add bookmark\" dialog's bookmark folder dropdown must be \"Bookmarks\"."
        )

        let addressBarBookmarkButtonValue = try? XCTUnwrap(
            addressBarBookmarkButton.value as? String,
            "It wasn't possible to get the value of the address bar bookmark button as String"
        )
        XCTAssertEqual( // The bookmark icon is already in a filled state and it isn't necessary to click the add button
            addressBarBookmarkButtonValue,
            "Bookmarked",
            "The accessibility value of the address bar bookmark button must be \"Bookmarked\", which indicates the icon in the filled state."
        )

        bookmarksMenu.clickAfterExistenceTestSucceeds()
        XCTAssertTrue( // And the bookmark is found in the Bookmarks menu
            app.menuItems[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmark in the \"Bookmarks\" menu with the title of the test page didn't appear with the expected title in a reasonable timeframe."
        )
    }

    func test_bookmarks_canBeAddedTo_byClickingBookmarksButtonInAddressBar() {
        openSiteToBookmark(bookmarkingViaDialog: false, escapingDialog: false)
        // In order to directly click the bookmark button in the address bar, we need to hover over something in the bar area
        optionsButton.hoverAfterExistenceTestSucceeds()
        addressBarBookmarkButton.clickAfterExistenceTestSucceeds()
        XCTAssertTrue( // Check Add Bookmark dialog for existence but don't click on it
            defaultBookmarkDialogButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog option button didn't appear with the expected title in a reasonable timeframe."
        )
        XCTAssertTrue(
            bookmarkDialogBookmarkFolderDropdown.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog's bookmark folder dropdown didn't appear with the expected title in a reasonable timeframe."
        )
        let bookmarkDialogBookmarkFolderDropdownValue = try? XCTUnwrap(
            bookmarkDialogBookmarkFolderDropdown.value as? String,
            "It wasn't possible to get the value of the \"Add bookmark\" dialog's bookmark folder dropdown as String"
        )

        XCTAssertEqual( // Bookmark dialog must default to "Bookmarks" folder
            bookmarkDialogBookmarkFolderDropdownValue,
            "Bookmarks",
            "The accessibility value of the \"Add bookmark\" dialog's bookmark folder dropdown must be \"Bookmarks\"."
        )
        let addressBarBookmarkButtonValue = try? XCTUnwrap(
            addressBarBookmarkButton.value as? String,
            "It wasn't possible to get the value of the address bar bookmark button as String"
        )
        XCTAssertEqual( // The bookmark icon is already in a filled state and it isn't necessary to click the add button
            addressBarBookmarkButtonValue,
            "Bookmarked",
            "The accessibility value of the address bar bookmark button must be \"Bookmarked\", which indicates the icon in the filled state."
        )

        bookmarksMenu.clickAfterExistenceTestSucceeds()
        XCTAssertTrue( // And the bookmark is found in the Bookmarks menu
            app.menuItems[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmark in the \"Bookmarks\" menu with the title of the test page didn't appear with the expected title in a reasonable timeframe."
        )
    }

    func test_favorites_canBeAddedTo_byClickingFavoriteThisPageMenuBarItem() {
        openSiteToBookmark(bookmarkingViaDialog: false, escapingDialog: false)
        bookmarksMenu.clickAfterExistenceTestSucceeds()
        favoriteThisPageMenuItem.clickAfterExistenceTestSucceeds()

        XCTAssertTrue( // Check Add Bookmark dialog for existence but don't click on it
            defaultBookmarkDialogButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog option button didn't appear with the expected title in a reasonable timeframe."
        )
        let addressBarBookmarkButtonValue = try? XCTUnwrap(
            addressBarBookmarkButton.value as? String,
            "It wasn't possible to get the value of the address bar bookmark button as String"
        )
        XCTAssertEqual( // The bookmark icon is already in a filled state and it isn't necessary to click the add button
            addressBarBookmarkButtonValue,
            "Bookmarked",
            "The accessibility value of the address bar bookmark button must be \"Bookmarked\", which indicates the icon in the filled state."
        )
        XCTAssertTrue( // Check Add Bookmark dialog for existence but don't click on it
            defaultBookmarkDialogButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog option button didn't appear with the expected title in a reasonable timeframe."
        )
        XCTAssertTrue(
            bookmarksDialogAddToFavoritesCheckbox.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The add to favorites checkbox in the add bookmark dialog didn't appear with the expected title in a reasonable timeframe."
        )

        let bookmarksDialogAddToFavoritesCheckboxValue = try? XCTUnwrap(
            bookmarksDialogAddToFavoritesCheckbox.value as? Bool,
            "It wasn't possible to get the value of the bookmarks dialog's add to favorites checkbox as Bool"
        )
        XCTAssertEqual( // The favorite checkbox in the dialog is already checked
            bookmarksDialogAddToFavoritesCheckboxValue,
            true,
            "The the value of the bookmarks dialog's add to favorites checkbox must be checked, which indicates that the item has been favorited."
        )
    }

    func test_favorites_canBeAddedTo_byClickingAddFavoriteInAddBookmarkPopover() {
        openSiteToBookmark(bookmarkingViaDialog: false, escapingDialog: false)
        // In order to directly click the bookmark button in the address bar, we need to hover over something in the bar area
        optionsButton.hoverAfterExistenceTestSucceeds()

        addressBarBookmarkButton.clickAfterExistenceTestSucceeds()
        XCTAssertTrue( // Check Add Bookmark dialog for existence before adding to favorites
            defaultBookmarkDialogButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog option button didn't appear with the expected title in a reasonable timeframe."
        )

        bookmarksDialogAddToFavoritesCheckbox.clickAfterExistenceTestSucceeds()
        let bookmarksDialogAddToFavoritesCheckboxValue = try? XCTUnwrap(
            bookmarksDialogAddToFavoritesCheckbox.value as? Bool,
            "It wasn't possible to get the value of the bookmarks dialog's add to favorites checkbox as Bool"
        )
        XCTAssertEqual( // The favorite checkbox in the dialog is already checked
            bookmarksDialogAddToFavoritesCheckboxValue,
            true,
            "The the value of the bookmarks dialog's add to favorites checkbox must be checked, which indicates that the item has been favorited."
        )
    }

    func test_favorites_canBeManuallyAddedTo_byClickingAddFavoriteInNewTabPage() throws {
        toggleBookmarksBarShowFavoritesOn()

        favoriteGridAddFavoriteButton.clickAfterExistenceTestSucceeds()
        let pageTitleForAddFavoriteDialog: String = try XCTUnwrap(pageTitle, "Couldn't unwrap page title")
        let urlForAddFavoriteDialog = try XCTUnwrap(urlForBookmarksBar, "Couldn't unwrap page url")
        app.typeText("\(pageTitleForAddFavoriteDialog)\t")
        app.typeURL(urlForAddFavoriteDialog)
        let newFavorite = app.links[pageTitleForAddFavoriteDialog]

        XCTAssertTrue(
            newFavorite.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The new favorite on the new tab page did not become available in a reasonable timeframe."
        )
    }

    func test_favorites_canBeAddedToFromManageBookmarksView() {
        openSiteToBookmark(bookmarkingViaDialog: true, escapingDialog: true)
        bookmarksMenu.clickAfterExistenceTestSucceeds()
        manageBookmarksMenuItem.clickAfterExistenceTestSucceeds()
        bookmarkTableCellViewFavIconImageView.hoverAfterExistenceTestSucceeds()
        bookmarkTableCellViewMenuButton.clickAfterExistenceTestSucceeds()

        contextualMenuAddBookmarkToFavoritesMenuItem.clickAfterExistenceTestSucceeds()
        XCTAssertTrue(
            bookmarksManagementAccessoryImageView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Bookmarks accessory view favorites indicator didn't load with the expected title in a reasonable timeframe."
        )
        let bookmarksManagementAccessoryImageViewValue = try? XCTUnwrap(
            bookmarksManagementAccessoryImageView.value as? String,
            "It wasn't possible to get the value of the bookmarks management accessory image view as String"
        )

        XCTAssertEqual(
            bookmarksManagementAccessoryImageViewValue,
            "Favorited",
            "The accessibility value of the favorite accessory view on the bookmark management view must be \"Favorited\"."
        )
    }

    func test_bookmarks_canBeViewedInBookmarkMenuItem() {
        openSiteToBookmark(bookmarkingViaDialog: true, escapingDialog: true)
        addressBarBookmarkButton.clickAfterExistenceTestSucceeds()

        bookmarksMenu.clickAfterExistenceTestSucceeds()
        let bookmarkedItemInMenu = app.menuItems[pageTitle]

        XCTAssertTrue(
            bookmarkedItemInMenu.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Bookmarked page couldn't be detected in the bookmarks menu in a reasonable timeframe."
        )
    }

    func test_bookmarks_canBeViewedInAddressBarBookmarkDialog() {
        openSiteToBookmark(bookmarkingViaDialog: true, escapingDialog: true)
        XCTAssertTrue(
            addressBarBookmarkButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Address bar bookmark button didn't load with the expected title in a reasonable timeframe."
        )
        let addressBarBookmarkButtonValue = try? XCTUnwrap(
            addressBarBookmarkButton.value as? String,
            "It wasn't possible to get the value of the bookmarks management accessory image view as String"
        )
        XCTAssertEqual(
            addressBarBookmarkButtonValue,
            "Bookmarked",
            "The accessibility value of the Address Bar Bookmark Button must be \"Bookmarked\"."
        )

        addressBarBookmarkButton.click()
        let bookMarkDialogBookmarkTitle = app.textFields[pageTitle]

        XCTAssertTrue(
            bookMarkDialogBookmarkTitle.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmarked url title wasn't found in the bookmark dialog in a bookmarked state in a reasonable timeframe."
        )
    }

    func test_bookmarksTab_canBeViewedViaMenuItemManageBookmarks() {
        openSiteToBookmark(bookmarkingViaDialog: true, escapingDialog: true)
        bookmarksMenu.clickAfterExistenceTestSucceeds()

        manageBookmarksMenuItem.clickAfterExistenceTestSucceeds()

        XCTAssertTrue(
            bookmarksTabPopup.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Bookmarks tab bookmarks popup didn't load with the expected title in a reasonable timeframe."
        )
    }

    func test_favorites_appearWithTheCorrectIndicatorInBookmarksTab() {
        openSiteToBookmark(bookmarkingViaDialog: true, escapingDialog: false)
        XCTAssertTrue(
            bookmarksDialogAddToFavoritesCheckbox.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The add to favorites checkbox in the add bookmark dialog didn't appear with the expected title in a reasonable timeframe."
        )
        let bookmarksDialogAddToFavoritesCheckboxValue = try? XCTUnwrap(
            bookmarksDialogAddToFavoritesCheckbox.value as? Bool,
            "It wasn't possible to get the value of the bookmarks dialog's add to favorites checkbox as Bool"
        )
        if bookmarksDialogAddToFavoritesCheckboxValue == false {
            bookmarksDialogAddToFavoritesCheckbox.click()
        }
        app.typeKey(.escape, modifierFlags: []) // Exit dialog

        bookmarksMenu.clickAfterExistenceTestSucceeds()
        manageBookmarksMenuItem.clickAfterExistenceTestSucceeds()
        XCTAssertTrue(
            bookmarksTabPopup.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Bookmarks tab bookmarks popup didn't load with the expected title in a reasonable timeframe."
        )
        XCTAssertTrue(
            bookmarksManagementAccessoryImageView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Bookmarks accessory view favorites indicator didn't load with the expected title in a reasonable timeframe."
        )
        let bookmarksManagementAccessoryImageViewValue = try? XCTUnwrap(
            bookmarksManagementAccessoryImageView.value as? String,
            "It wasn't possible to get the value of the bookmarks management accessory image view as String"
        )

        XCTAssertEqual(
            bookmarksManagementAccessoryImageViewValue,
            "Favorited",
            "The accessibility value of the favorite accessory view on the bookmark management view must be \"Favorited\"."
        )
    }

    func test_favorites_appearInNewTabFavoritesGrid() throws {
        openSiteToBookmark(bookmarkingViaDialog: true, escapingDialog: false)
        XCTAssertTrue(
            bookmarksDialogAddToFavoritesCheckbox.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The add to favorites checkbox in the add bookmark dialog didn't appear with the expected title in a reasonable timeframe."
        )
        let bookmarksDialogAddToFavoritesCheckboxValue = try? XCTUnwrap(
            bookmarksDialogAddToFavoritesCheckbox.value as? Bool,
            "It wasn't possible to get the value of the bookmarks dialog's add to favorites checkbox as Bool"
        )
        if bookmarksDialogAddToFavoritesCheckboxValue == false {
            bookmarksDialogAddToFavoritesCheckbox.click()
        }
        app.typeKey(.escape, modifierFlags: []) // Exit dialog

        toggleBookmarksBarShowFavoritesOn()
        let unwrappedPageTitle = try XCTUnwrap(pageTitle, "It wasn't possible to unwrap pageTitle")
        let firstFavoriteInGridMatchingTitle = app.staticTexts[unwrappedPageTitle].firstMatch

        XCTAssertTrue(
            firstFavoriteInGridMatchingTitle.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The favorited item in the grid did not become available in a reasonable timeframe."
        )
    }

    func test_favorites_canBeRemovedFromAddressBarBookmarkDialog() {
        openSiteToBookmark(bookmarkingViaDialog: true, escapingDialog: false)
        XCTAssertTrue(
            bookmarksDialogAddToFavoritesCheckbox.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The add to favorites checkbox in the add bookmark dialog didn't appear with the expected title in a reasonable timeframe."
        )
        let bookmarksDialogAddToFavoritesCheckboxValue = try? XCTUnwrap(
            bookmarksDialogAddToFavoritesCheckbox.value as? Bool,
            "It wasn't possible to get the value of the bookmarks dialog's add to favorites checkbox as Bool"
        )
        if bookmarksDialogAddToFavoritesCheckboxValue == false {
            bookmarksDialogAddToFavoritesCheckbox.click() // Favorite the bookmark
        }
        app.typeKey(.escape, modifierFlags: []) // Exit dialog

        XCTAssertTrue(
            addressBarBookmarkButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Address bar bookmark button didn't load with the expected title in a reasonable timeframe."
        )
        let addressBarBookmarkButtonValue = try? XCTUnwrap(
            addressBarBookmarkButton.value as? String,
            "It wasn't possible to get the value of the bookmarks management accessory image view as String"
        )
        XCTAssertEqual(
            addressBarBookmarkButtonValue,
            "Bookmarked",
            "The accessibility value of the Address Bar Bookmark Button must be \"Bookmarked\"."
        )
        addressBarBookmarkButton.click()
        XCTAssertTrue(
            bookmarksDialogAddToFavoritesCheckbox.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The add to favorites checkbox in the add bookmark dialog didn't appear with the expected title in a reasonable timeframe."
        )
        let bookmarksDialogAddToFavoritesCheckboxNewValue = try? XCTUnwrap(
            bookmarksDialogAddToFavoritesCheckbox.value as? Bool,
            "It wasn't possible to get the value of the bookmarks dialog's add to favorites checkbox as Bool"
        )
        if bookmarksDialogAddToFavoritesCheckboxNewValue == true {
            bookmarksDialogAddToFavoritesCheckbox.click() // Unfavorite the bookmark
        }
        let bookmarksDialogAddToFavoritesCheckboxLastValue = try? XCTUnwrap(
            bookmarksDialogAddToFavoritesCheckbox.value as? Bool,
            "It wasn't possible to get the value of the bookmarks dialog's add to favorites checkbox as Bool"
        )
        let addToFavoritesLabel = "Add to Favorites"

        XCTAssertEqual(
            bookmarksDialogAddToFavoritesCheckboxLastValue,
            false,
            "The favorite checkbox in the add bookmark dialog must now be unchecked"
        )
        XCTAssertEqual(
            bookmarksDialogAddToFavoritesCheckbox.label,
            addToFavoritesLabel,
            "The label of the add to favorites checkbox must now be \"\(addToFavoritesLabel)\""
        )
    }

    func test_favorites_canBeRemovedFromManageBookmarks() {
        openSiteToBookmark(bookmarkingViaDialog: true, escapingDialog: false)
        XCTAssertTrue(
            bookmarksDialogAddToFavoritesCheckbox.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The add to favorites checkbox in the add bookmark dialog didn't appear with the expected title in a reasonable timeframe."
        )
        let bookmarksDialogAddToFavoritesCheckboxValue = try? XCTUnwrap(
            bookmarksDialogAddToFavoritesCheckbox.value as? Bool,
            "It wasn't possible to get the value of the bookmarks dialog's add to favorites checkbox as Bool"
        )
        if bookmarksDialogAddToFavoritesCheckboxValue == false {
            bookmarksDialogAddToFavoritesCheckbox.click() // Favorite the bookmark
        }
        app.typeKey(.escape, modifierFlags: []) // Exit dialog

        bookmarksMenu.clickAfterExistenceTestSucceeds()
        manageBookmarksMenuItem.clickAfterExistenceTestSucceeds()
        bookmarkTableCellViewFavIconImageView.hoverAfterExistenceTestSucceeds()
        bookmarkTableCellViewMenuButton.clickAfterExistenceTestSucceeds()
        contextualMenuRemoveBookmarkFromFavoritesMenuItem.clickAfterExistenceTestSucceeds()

        XCTAssertTrue(
            bookmarksManagementAccessoryImageView.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "Bookmarks accessory view favorites indicator didn't disappear from the view in a reasonable timeframe."
        )
    }

    func test_favorites_canBeRemovedFromNewTabViaContextClick() throws {
        toggleBookmarksBarShowFavoritesOn()
        openSiteToBookmark(bookmarkingViaDialog: true, escapingDialog: false)
        XCTAssertTrue(
            bookmarksDialogAddToFavoritesCheckbox.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The add to favorites checkbox in the add bookmark dialog didn't appear with the expected title in a reasonable timeframe."
        )
        let bookmarksDialogAddToFavoritesCheckboxValue = try? XCTUnwrap(
            bookmarksDialogAddToFavoritesCheckbox.value as? Bool,
            "It wasn't possible to get the value of the bookmarks dialog's add to favorites checkbox as Bool"
        )
        if bookmarksDialogAddToFavoritesCheckboxValue == false {
            bookmarksDialogAddToFavoritesCheckbox.click() // Favorite the bookmark
        }
        app.typeKey(.escape, modifierFlags: []) // Exit dialog
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Close all windows
        app.typeKey("n", modifierFlags: .command) // New window

        let unwrappedPageTitle = try XCTUnwrap(pageTitle, "It wasn't possible to unwrap pageTitle")
        let firstFavoriteInGridMatchingTitle = app.links[unwrappedPageTitle].firstMatch
        XCTAssertTrue(
            firstFavoriteInGridMatchingTitle.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The favorited item in the grid did not become available in a reasonable timeframe."
        )
        firstFavoriteInGridMatchingTitle.rightClick()
        removeFavoritesContextMenuItem.clickAfterExistenceTestSucceeds()

        XCTAssertTrue(
            firstFavoriteInGridMatchingTitle.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "The favorited item in the grid did not disappear in a reasonable timeframe."
        )
    }

    func test_bookmark_canBeRemovedViaAddressBarIconClick() {
        toggleShowBookmarksBarAlwaysOn()
        app.typeKey("w", modifierFlags: [.command, .option, .shift])
        app.typeKey("n", modifierFlags: .command)
        openSiteToBookmark(bookmarkingViaDialog: true, escapingDialog: true)

        addressBarBookmarkButton.clickAfterExistenceTestSucceeds()
        defaultBookmarkOtherButton.clickAfterExistenceTestSucceeds()
        app.typeKey(.escape, modifierFlags: []) // Exit dialog
        app.typeKey("w", modifierFlags: [.command, .option, .shift])
        app.typeKey("n", modifierFlags: .command)

        XCTAssertTrue(
            app.staticTexts[pageTitle].waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "Since there is no bookmark of the page, and we show bookmarks in the bookmark bar, the title of the page should not appear in a new browser window anywhere."
        )
    }

    func test_bookmark_canBeRemovedFromBookmarksTabViaHoverAndContextMenu() {
        app.typeKey("w", modifierFlags: [.command, .option, .shift])
        app.typeKey("n", modifierFlags: .command)
        openSiteToBookmark(bookmarkingViaDialog: true, escapingDialog: true)

        bookmarksMenu.clickAfterExistenceTestSucceeds()
        manageBookmarksMenuItem.clickAfterExistenceTestSucceeds()
        bookmarkTableCellViewFavIconImageView.hoverAfterExistenceTestSucceeds()
        bookmarkTableCellViewMenuButton.clickAfterExistenceTestSucceeds()
        contextualMenuDeleteBookmarkMenuItem.clickAfterExistenceTestSucceeds()
        app.typeKey("w", modifierFlags: [.command, .option, .shift])
        app.typeKey("n", modifierFlags: .command)

        XCTAssertTrue(
            app.staticTexts[pageTitle].waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "Since there is no bookmark of the page, and we show bookmarks in the bookmark bar, the title of the page should not appear in a new browser window anywhere."
        )
    }

    func test_bookmark_canBeRemovedFromBookmarksBarViaRightClick() {
//        This test uses coordinates (instead of accessibility IDs) to address the elements of the right click. As the writer of this test, I see this
//        as a fragile test hook. However, I think it is preferable to making changes to the UI element it tests for this test alone. The reason is
//        that the bookmark item on the bookmark bar isn't yet an accessibility-enabled UI element and doesn't appear to have a natural anchor point
//        from which we can set its accessibility values without redesigning it. However, redesigning a road-tested UI element for a single test isn't
//        a
//        good idea, since the road-testing is also (valuable) testing and we don't want a single test to be the driver of a possible behavioral
//        change in existing interface.
//
//        My advice is to keep this as-is for now, with an awareness that it can fail if the coordinates of the items in the right-click menu change,
//        or if the system where the testing is done has accessibility settings which change scaling. When the time comes to update this element, into
//        SwiftUI, or into a general accessibility revision (for end-user accessibility rather than UI test accessibility), that will be the natural
//        time to correct this test and give it accessibility ID access. Until then, I have added some hinting in the failure reason to explain why
//        this test can fail while the app is working correctly. -Halle Winkler

        toggleShowBookmarksBarAlwaysOn()
        app.typeKey("w", modifierFlags: [.command, .option, .shift])
        app.typeKey("n", modifierFlags: .command)
        openSiteToBookmark(bookmarkingViaDialog: true, escapingDialog: true)
        app.typeKey("w", modifierFlags: [.command, .option, .shift])
        app.typeKey("n", modifierFlags: .command)

        XCTAssertTrue(
            bookmarksBarCollectionView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmarks bar collection view failed to become available in a reasonable timeframe."
        )
        let bookmarkBarBookmarkIcon = bookmarksBarCollectionView.images.firstMatch
        XCTAssertTrue(
            bookmarkBarBookmarkIcon.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmarks bar bookmark icon failed to become available in a reasonable timeframe."
        )
        let bookmarkBarBookmarkIconCoordinate = bookmarkBarBookmarkIcon.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        var deleteContextMenuItemCoordinate: XCUICoordinate
        if #available(macOS 15.0, *) {
            deleteContextMenuItemCoordinate = bookmarkBarBookmarkIcon.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 8.0))
        } else {
            deleteContextMenuItemCoordinate = bookmarkBarBookmarkIcon.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 9.0))
        }

        bookmarkBarBookmarkIconCoordinate.rightClick()
        deleteContextMenuItemCoordinate.click()
        app.typeKey("w", modifierFlags: [.command, .option, .shift])
        app.typeKey("n", modifierFlags: .command)

        XCTAssertTrue(
            app.staticTexts[pageTitle].waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "Since there is no bookmark of the page, and we show bookmarks in the bookmark bar, the title of the page should not appear in a new browser window anywhere. In this specific test, it is highly probable that the reason for a failure (when this area of the app appears to be working correctly) is the contextual menu being rearranged, since it has to address the menu elements by coordinate."
        )
    }
}

private extension BookmarksAndFavoritesTests {
    /// Reset the bookmarks so we can rely on a single bookmark's existence
    func resetBookmarks() {
        app.typeKey("n", modifierFlags: [.command]) // Can't use debug menu without a window
        XCTAssertTrue(
            resetBookMarksMenuItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Reset bookmarks menu item didn't become available in a reasonable timeframe."
        )
        resetBookMarksMenuItem.click()
    }

    /// Make sure that we can reply on the bookmarks bar always appearing
    func toggleShowBookmarksBarAlwaysOn() {
        let settings = app.menuItems["MainMenu.preferencesMenuItem"]
        XCTAssertTrue(
            settings.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Reset bookmarks menu item didn't become available in a reasonable timeframe."
        )

        settings.click()

        XCTAssertTrue(
            settingsAppearanceButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The user settings appearance section button didn't become available in a reasonable timeframe."
        )
        settingsAppearanceButton.click(forDuration: 0.5, thenDragTo: settingsAppearanceButton)
        XCTAssertTrue(
            showBookmarksBarPreferenceToggle.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The toggle for showing the bookmarks bar didn't become available in a reasonable timeframe."
        )

        let showBookmarksBarIsChecked = try? XCTUnwrap(
            showBookmarksBarPreferenceToggle.value as? Bool,
            "It wasn't possible to get the \"Show bookmarks bar\" value as a Bool"
        )
        if showBookmarksBarIsChecked == false {
            showBookmarksBarPreferenceToggle.click()
        }
        XCTAssertTrue(
            showBookmarksBarPopup.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Show Bookmarks Bar\" popup button didn't become available in a reasonable timeframe."
        )
        showBookmarksBarPopup.click()
        XCTAssertTrue(
            showBookmarksBarAlways.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Show Bookmarks Bar Always\" button didn't become available in a reasonable timeframe."
        )
        showBookmarksBarAlways.click()
    }

    /// Make sure that appearance tab has been used to set "show favorites" to true
    func toggleBookmarksBarShowFavoritesOn() {
        app.openNewTab()
        addressBarTextField.typeURL(URL(string: "duck://settings")!)

        XCTAssertTrue(
            settingsAppearanceButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The user settings appearance section button didn't become available in a reasonable timeframe."
        )
        settingsAppearanceButton.click(forDuration: 0.5, thenDragTo: settingsAppearanceButton)

        XCTAssertTrue(
            showFavoritesPreferenceToggle.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The user settings appearance section show favorites toggle didn't become available in a reasonable timeframe."
        )
        let showFavoritesPreferenceToggleIsChecked = showFavoritesPreferenceToggle.value as? Bool
        if showFavoritesPreferenceToggleIsChecked == false { // If untoggled,
            showFavoritesPreferenceToggle.click() // Toggle "show favorites"
        }
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Close settings and everything else
        app.typeKey("n", modifierFlags: .command) // New window
    }

    /// Open the initial site to be bookmarked, bookmarking it and/or escaping out of the dialog only if needed
    /// - Parameter bookmarkingViaDialog: open bookmark dialog, adding bookmark
    /// - Parameter escapingDialog: `esc` key to leave dialog
    func openSiteToBookmark(bookmarkingViaDialog: Bool, escapingDialog: Bool) {
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )
        addressBarTextField.typeURL(urlForBookmarksBar)
        XCTAssertTrue(
            app.windows.webViews[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
        if bookmarkingViaDialog {
            app.typeKey("d", modifierFlags: [.command]) // Add bookmark
            if escapingDialog {
                app.typeKey(.escape, modifierFlags: []) // Exit dialog
            }
        }
    }
}
