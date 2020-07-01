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

    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var goBackButton: NSButton!
    @IBOutlet weak var goForwardButton: NSButton!
    @IBOutlet weak var reloadButton: NSButton!

    private var suggestionsWindowController: NSWindowController?

    private var urlCancelable: AnyCancellable?
    private var searchSuggestionsCancelable: AnyCancellable?
    private var navigationButtonsCancelables = Set<AnyCancellable>()

    private let suggestionsViewModel = SuggestionsViewModel(suggestions: Suggestions())
    var tabViewModel: TabViewModel? {
        didSet {
            bindUrl()
            bindNavigationButtons()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        searchField.delegate = self

        initSuggestionsWindow()
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
        searchField.stringValue = tabViewModel.addressBarString
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
        guard let url = URL.makeURL(from: searchField.stringValue) else {
            os_log("%s: Making url from address bar string failed", log: OSLog.Category.general, type: .error, className)
            return
        }
        tabViewModel.tab.url = url
    }

    // MARK: - Suggestions window

    private func initSuggestionsWindow() {
        let storyboard = NSStoryboard(name: "Suggestions", bundle: nil)
        guard let suggestionsWindowController = storyboard.instantiateController(
                withIdentifier: "SuggestionsWindowController") as? NSWindowController else {
            //todo os_log
            return
        }
        self.suggestionsWindowController = suggestionsWindowController

        guard let suggestionsViewController = suggestionsWindowController.contentViewController as? SuggestionsViewController else {
            //todo os_log
            return
        }
        suggestionsViewController.suggestionsViewModel = suggestionsViewModel
    }

    private func showSuggestionsWindow() {
        guard let window = view.window, let suggestionsWindow = suggestionsWindowController?.window else {
            //todo os_log
            return
        }

        if !suggestionsWindow.isVisible {
            window.addChildWindow(suggestionsWindow, ordered: .above)
        }

        // Layout the window
        let padding = CGFloat(3)
        suggestionsWindow.setFrame(NSRect(x: 0, y: 0, width: searchField.frame.width + 2 * padding, height: 0), display: true)

        var point = searchField.frame.origin
        point.y -= padding
        point.x -= padding

        let converted = view.convert(point, to: nil)
        let screen = window.convertPoint(toScreen: converted)
        suggestionsWindow.setFrameTopLeftPoint(screen)
    }

    private func hideSuggestionsWindow() {
        guard let window = view.window, let suggestionsWindow = suggestionsWindowController?.window else {
            //todo os_log
            return
        }

        if !suggestionsWindow.isVisible { return }

        window.removeChildWindow(suggestionsWindow)
        suggestionsWindow.parent?.removeChildWindow(suggestionsWindow)
        suggestionsWindow.orderOut(nil)
    }
    
}

extension NavigationBarViewController: NSSearchFieldDelegate {

    func controlTextDidEndEditing(_ obj: Notification) {
        let textMovement = obj.userInfo?["NSTextMovement"] as? Int
        if textMovement == NSReturnTextMovement {
            setUrl()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        print("controlTextDidChange")
        suggestionsViewModel.suggestions.getSuggestions(for: searchField.stringValue)

        if searchField.stringValue.isEmpty {
            hideSuggestionsWindow()
        } else {
            showSuggestionsWindow()
        }
    }

}

fileprivate extension URL {

    static func makeSearchUrl(from searchQuery: String) -> URL? {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            var searchUrl = Self.duckDuckGo
            searchUrl = try searchUrl.addParameter(name: DuckDuckGoParameters.search.rawValue, value: trimmedQuery)
            return searchUrl
        } catch let error {
            os_log("URL extension: %s", log: OSLog.Category.general, type: .error, error.localizedDescription)
            return nil
        }
    }

    static func makeURL(from addressBarString: String) -> URL? {
        if let addressBarUrl = addressBarString.url {
            return addressBarUrl
        }

        if let searchUrl = URL.makeSearchUrl(from: addressBarString) {
            return searchUrl
        }

        os_log("URL extension: Making URL from %s failed", log: OSLog.Category.general, type: .error, addressBarString)
        return nil
    }

}
