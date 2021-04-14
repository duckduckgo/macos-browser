//
//  PreferencesAboutViewController.swift
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

import Foundation

final class PreferencesAboutViewController: NSViewController {

    enum Constants {
        static let storyboardName = "Preferences"
        static let identifier = "PreferencesAboutViewController"
    }

    static func create() -> PreferencesAboutViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    @IBOutlet var versionLabel: NSTextField!
    @IBOutlet var sendFeedbackButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        let version = AppVersion()
        versionLabel.stringValue = UserText.versionLabel(version: version.versionNumber, build: version.buildNumber)

        #if FEEDBACK
        sendFeedbackButton.isHidden = false
        #else
        sendFeedbackButton.isHidden = true
        #endif
    }

    @IBAction func sendFeedback(_ sender: NSButton) {
#if FEEDBACK
        openURLInNewTab(URL.feedback)
#else
        assertionFailure("\(#file): Failed to open feedback link")
#endif
    }

    @IBAction func openMoreInfoTab(_ sender: NSButton) {
        openURLInNewTab(URL.aboutDuckDuckGo)
    }

    private func openURLInNewTab(_ url: URL) {
        guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController,
              windowController.window?.isKeyWindow == true else {
            WindowsManager.openNewWindow(with: URL.feedback)
            return
        }

        let mainViewController = windowController.mainViewController

        DefaultConfigurationStorage.shared.log()
        ConfigurationManager.shared.log()

        let tab = Tab()
        tab.url = url

        let tabCollectionViewModel = mainViewController.tabCollectionViewModel
        tabCollectionViewModel.append(tab: tab)
    }
}
