//
//  NavigationBarViewController.swift
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

import Cocoa
import Combine
import os.log

class NavigationBarViewController: NSViewController {

    @IBOutlet weak var autocompleteSearchField: AutocompleteSearchField!
    @IBOutlet weak var goBackButton: NSButton!
    @IBOutlet weak var goForwardButton: NSButton!
    @IBOutlet weak var reloadButton: NSButton!
    @IBOutlet weak var settingsButton: NSButton!

    private var urlCancelable: AnyCancellable?
    private var searchSuggestionsCancelable: AnyCancellable?
    private var navigationButtonsCancelables = Set<AnyCancellable>()

    var tabViewModel: TabViewModel? {
        didSet {
            bindUrl()
            bindNavigationButtons()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        autocompleteSearchField.searchFieldDelegate = self
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        autocompleteSearchField.viewDidLayout()
    }

    @IBAction func goBackAction(_ sender: NSButton) {
        tabViewModel?.tab.goBack()
    }

    @IBAction func goForwardAction(_ sender: NSButton) {
        tabViewModel?.tab.goForward()
    }

    @IBAction func reloadAction(_ sender: NSButton) {
        tabViewModel?.tab.reload()
    }

    @IBAction func settingsButtonAction(_ sender: NSButton) {
    }
    
    private func bindUrl() {
        urlCancelable?.cancel()
        urlCancelable = tabViewModel?.tab.$url.sinkAsync { _ in self.refreshSearchField() }
    }

    private func bindNavigationButtons() {
        navigationButtonsCancelables.forEach { $0.cancel() }
        navigationButtonsCancelables.removeAll()

        tabViewModel?.$canGoBack.sinkAsync { _ in self.setNavigationButtons() } .store(in: &navigationButtonsCancelables)
        tabViewModel?.$canGoForward.sinkAsync { _ in self.setNavigationButtons() } .store(in: &navigationButtonsCancelables)
        tabViewModel?.$canReload.sinkAsync { _ in self.setNavigationButtons() } .store(in: &navigationButtonsCancelables)
    }

    private func refreshSearchField() {
        guard let tabViewModel = tabViewModel else {
            os_log("%s: Property tabViewModel is nil", log: OSLog.Category.general, type: .error, className)
            return
        }
        autocompleteSearchField.stringValue = tabViewModel.addressBarString
    }

    private func setNavigationButtons() {
        goBackButton.isEnabled = tabViewModel?.canGoBack ?? false
        goForwardButton.isEnabled = tabViewModel?.canGoForward ?? false
        reloadButton.isEnabled = tabViewModel?.canReload ?? false
    }

    private func setUrl() {
        guard let tabViewModel = tabViewModel else {
            os_log("%s: Property tabViewModel is nil", log: OSLog.Category.general, type: .error, className)
            return
        }
        guard let url = URL.makeURL(from: autocompleteSearchField.stringValue) else {
            os_log("%s: Making url from address bar string failed", log: OSLog.Category.general, type: .error, className)
            return
        }
        tabViewModel.tab.url = url
    }

}

extension NavigationBarViewController: AutocompleteSearchFieldDelegate {

    func autocompleteSearchField(_ autocompleteSearchField: AutocompleteSearchField, didConfirmStringValue: String) {
        setUrl()
    }

}
