//
//  BrowserImportViewController.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import AppKit

protocol BrowserImportViewControllerDelegate: AnyObject {

    func browserImportViewController(_ viewController: BrowserImportViewController, didChangeSelectedImportOptions options: [DataImport.DataType])
    func browserImportViewControllerRequestedParentViewRefresh(_ viewController: BrowserImportViewController)

}

final class BrowserImportViewController: NSViewController {

    enum Constants {
        static let storyboardName = "DataImport"
        static let identifier = "BrowserImportViewController"
        static let browserWarningBarHeight: CGFloat = 32.0
    }

    static func create(with browser: ThirdPartyBrowser) -> BrowserImportViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)

        return storyboard.instantiateController(identifier: Constants.identifier) { (coder) -> BrowserImportViewController? in
            return BrowserImportViewController(coder: coder, browser: browser)
        }
    }

    @IBOutlet var importOptionsStackView: NSStackView!

    @IBOutlet var profileSelectionLabel: NSTextField!
    @IBOutlet var profileSelectionPopUpButton: NSPopUpButton!

    @IBOutlet var bookmarksCheckbox: NSButton!
    @IBOutlet var bookmarksWarningLabel: NSTextField!
    @IBOutlet var passwordsCheckbox: NSButton!
    @IBOutlet var passwordsWarningLabel: NSTextField!

    weak var delegate: BrowserImportViewControllerDelegate?

    var selectedImportOptions: [DataImport.DataType] {
        var options = [DataImport.DataType]()

        if bookmarksCheckbox.state == .on && !bookmarksCheckbox.isHidden {
            options.append(.bookmarks)
        }

        if passwordsCheckbox.state == .on && !passwordsCheckbox.isHidden {
            options.append(.logins)
        }

        return options
    }

    var selectedProfile: DataImport.BrowserProfile? {
        guard let selectedProfile = profileSelectionPopUpButton.selectedItem else {
            // If there is no selected item, there should only be one item in the list.
            return profileList?.validImportableProfiles.first
        }

        return profileList?.validImportableProfiles.first { $0.profileURL == selectedProfile.representedObject as? URL }
    }

    let browser: ThirdPartyBrowser
    let profileList: DataImport.BrowserProfileList?

    init?(coder: NSCoder, browser: ThirdPartyBrowser) {
        self.browser = browser
        self.profileList = browser.browserProfiles()

        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        importOptionsStackView.setCustomSpacing(18, after: profileSelectionPopUpButton)

        // Update the profile picker:
        if let profileList, profileList.shouldShowProfilePicker {
            profileSelectionPopUpButton.displayBrowserProfiles(profiles: profileList.validImportableProfiles, defaultProfile: profileList.defaultProfile)
        } else {
            profileSelectionLabel.isHidden = true
            profileSelectionPopUpButton.isHidden = true
            profileSelectionPopUpButton.removeAllItems()
        }

        updateImportOptions()
    }

    private func updateImportOptions() {
        switch browser {
        case .safari, .safariTechnologyPreview:
            bookmarksCheckbox.title = UserText.bookmarkImportBookmarksAndFavorites
            guard let safariMajorVersion = SafariVersionReader.getMajorVersion() else {
                assertionFailure("Failed to get version of Safari")
                passwordsWarningLabel.isHidden = false
                return
            }
            passwordsWarningLabel.stringValue = UserText.requiresSafari15warning
            passwordsWarningLabel.isHidden = safariMajorVersion >= 15
            bookmarksWarningLabel.isHidden = true

        case .tor:
            bookmarksCheckbox.title = UserText.bookmarkImportBookmarks

            guard validateProfileData() else { break }
            passwordsCheckbox.state = .off
            passwordsCheckbox.isEnabled = false

            passwordsWarningLabel.stringValue = UserText.torImportPasswordsUnavailable
            passwordsWarningLabel.isHidden = false

        case .brave, .chrome, .chromium, .coccoc, .edge, .firefox, .opera, .operaGX, .vivaldi, .yandex,
             .bitwarden, .lastPass, .onePassword7, .onePassword8:

            bookmarksCheckbox.title = UserText.bookmarkImportBookmarks

            validateProfileData()
        }

        selectedImportOptionsChanged(nil)
    }

    @discardableResult
    private func validateProfileData() -> Bool {
        guard let result = selectedProfile?.validateProfileData() else {
            passwordsCheckbox.isEnabled = false
            passwordsCheckbox.state = .off
            bookmarksCheckbox.isEnabled = false
            bookmarksCheckbox.state = .off
            bookmarksWarningLabel.isHidden = true

            guard let profileURL = selectedProfile?.profileURL ?? browser.profilesDirectory() else {
                passwordsWarningLabel.isHidden = true
                return false
            }
            passwordsWarningLabel.stringValue = UserText.browserProfileDataFileNotFound(atPath: profileURL.path.abbreviatingWithTildeInPath)
            passwordsWarningLabel.isHidden = false

            return false
        }

        switch result.logins {
        case .available, .unsupported:
            passwordsCheckbox.isEnabled = true
            passwordsCheckbox.state = .on
            passwordsWarningLabel.isHidden = true

        case .unavailable(path: let path):
            passwordsCheckbox.isEnabled = false
            passwordsCheckbox.state = .off
            passwordsWarningLabel.isHidden = false
            passwordsWarningLabel.stringValue = UserText.browserDataFileNotFound(atPath: path.abbreviatingWithTildeInPath)
        }

        switch result.bookmarks {
        case .available, .unsupported:
            bookmarksCheckbox.isEnabled = true
            bookmarksCheckbox.state = .on
            bookmarksWarningLabel.isHidden = true

        case .unavailable(path: let path):
            bookmarksCheckbox.isEnabled = false
            bookmarksCheckbox.state = .off
            bookmarksWarningLabel.isHidden = false
            bookmarksWarningLabel.stringValue = UserText.browserDataFileNotFound(atPath: path.abbreviatingWithTildeInPath)
        }

        return true
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        delegate?.browserImportViewControllerRequestedParentViewRefresh(self)
    }

    @IBAction func profileSelectionPopUpAction(_ sender: NSPopUpButton) {
        updateImportOptions()
    }

    @IBAction func selectedImportOptionsChanged(_ sender: Any?) {
        delegate?.browserImportViewController(self, didChangeSelectedImportOptions: selectedImportOptions)
    }

}

extension NSPopUpButton {

    fileprivate func displayBrowserProfiles(profiles: [DataImport.BrowserProfile], defaultProfile: DataImport.BrowserProfile?) {
        removeAllItems()

        var selectedSourceIndex: Int?

        for (index, profile) in profiles.enumerated() {
            // Duplicate profile names won‘t be added to the Popup: need to deduplicate
            var profileName: String
            var i = 0
            repeat {
                profileName = profile.profileName + (i > 0 ? " - \(i)" : "")
                i += 1
            } while itemTitles.contains(profileName)

            addItem(withTitle: profileName, representedObject: profile.profileURL)

            if profile.profileURL == defaultProfile?.profileURL {
                selectedSourceIndex = index
            }
        }

        selectItem(at: selectedSourceIndex ?? 0)
    }

}
