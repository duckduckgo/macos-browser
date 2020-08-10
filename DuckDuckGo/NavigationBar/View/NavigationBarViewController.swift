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

    private var tabCollectionViewModel: TabCollectionViewModel

    private var selectedTabViewModelCancelable: AnyCancellable?
    private var urlCancelable: AnyCancellable?
    private var searchSuggestionsCancelable: AnyCancellable?
    private var navigationButtonsCancelables = Set<AnyCancellable>()

    required init?(coder: NSCoder) {
        fatalError("BrowserTabViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        autocompleteSearchField.searchFieldDelegate = self
        bindSelectedTabViewModel()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        autocompleteSearchField.viewDidLayout()
    }

    @IBAction func goBackAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        selectedTabViewModel.tab.goBack()
    }

    @IBAction func goForwardAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        selectedTabViewModel.tab.goForward()
    }

    @IBAction func reloadAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        selectedTabViewModel.tab.reload()
    }

    @IBAction func settingsButtonAction(_ sender: NSButton) {
    }

    private func bindSelectedTabViewModel() {
        selectedTabViewModelCancelable = tabCollectionViewModel.$selectedTabViewModel.sinkAsync { [weak self] _ in
            self?.bindUrl()
            self?.bindNavigationButtons()
        }
    }
    
    private func bindUrl() {
        urlCancelable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            autocompleteSearchField.stringValue = ""
            return
        }
        urlCancelable = selectedTabViewModel.$addressBarString.sinkAsync { [weak self] _ in self?.refreshSearchField() }
    }

    private func bindNavigationButtons() {
        navigationButtonsCancelables.forEach { $0.cancel() }
        navigationButtonsCancelables.removeAll()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            goBackButton.isEnabled = false
            goForwardButton.isEnabled = false
            reloadButton.isEnabled = false
            return
        }
        selectedTabViewModel.$canGoBack.sinkAsync { [weak self] _ in self?.setNavigationButtons() } .store(in: &navigationButtonsCancelables)
        selectedTabViewModel.$canGoForward.sinkAsync { [weak self] _ in self?.setNavigationButtons() } .store(in: &navigationButtonsCancelables)
        selectedTabViewModel.$canReload.sinkAsync { [weak self] _ in self?.setNavigationButtons() } .store(in: &navigationButtonsCancelables)
    }

    private func makeSearchFieldFirstResponder() {
        guard let window = view.window else {
            os_log("%s: Window not available", log: OSLog.Category.general, type: .error, className)
            return
        }

        window.makeFirstResponder(autocompleteSearchField)
    }

    private func refreshSearchField() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }
        let addressBarString = selectedTabViewModel.addressBarString
        autocompleteSearchField.stringValue = addressBarString
        if addressBarString == "" {
            makeSearchFieldFirstResponder()
        }
    }

    private func setNavigationButtons() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        goBackButton.isEnabled = selectedTabViewModel.canGoBack
        goForwardButton.isEnabled = selectedTabViewModel.canGoForward
        reloadButton.isEnabled = selectedTabViewModel.canReload
    }

    private func setUrl() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }
        guard let url = URL.makeURL(from: autocompleteSearchField.stringValue) else {
            os_log("%s: Making url from address bar string failed", log: OSLog.Category.general, type: .error, className)
            return
        }
        selectedTabViewModel.tab.url = url
    }

}

extension NavigationBarViewController: AutocompleteSearchFieldDelegate {

    func autocompleteSearchField(_ autocompleteSearchField: AutocompleteSearchField, didConfirmStringValue: String) {
        setUrl()
    }

}
