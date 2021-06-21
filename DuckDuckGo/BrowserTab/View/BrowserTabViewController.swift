//
//  BrowserTabViewController.swift
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
import WebKit
import os.log
import Combine
import SwiftUI
import BrowserServicesKit

final class BrowserTabViewController: NSViewController {

    @IBOutlet weak var errorView: NSView!
    @IBOutlet weak var homepageView: NSView!
    weak var webView: WebView?

    var tabViewModel: TabViewModel?

    private let tabCollectionViewModel: TabCollectionViewModel
    private var urlCancellable: AnyCancellable?
    private var selectedTabViewModelCancellable: AnyCancellable?
    private var isErrorViewVisibleCancellable: AnyCancellable?

    private var contextMenuExpected = false
    private var contextMenuLink: URL?
    private var contextMenuImage: URL?

    required init?(coder: NSCoder) {
        fatalError("BrowserTabViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    @IBSegueAction func createHomepageViewController(_ coder: NSCoder) -> NSViewController? {
        guard let controller = HomepageViewController(coder: coder,
                                                      tabCollectionViewModel: tabCollectionViewModel,
                                                      bookmarkManager: LocalBookmarkManager.shared) else {
            fatalError("BrowserTabViewController: Failed to init HomepageViewController")
        }
        return controller
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        subscribeToSelectedTabViewModel()
        subscribeToIsErrorViewVisible()
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] viewModel in
            self?.updateInterface(url: viewModel?.tab.url)
            self?.subscribeToIsErrorViewVisible()
        }
    }

    /// Takes a URL and decided what to do with the UI. There are three states:
    ///
    /// 1. No URL is provided, so the webview should be hidden in favor of showing the default UI elements.
    /// 2. A URL is provided for the first time, so the webview should be added as a subview and the URL should be loaded.
    /// 3. A URL is provided after already adding the webview, so the webview should be reloaded.
    private func updateInterface(url: URL?) {
        changeWebView()

        if tabCollectionViewModel.selectedTabViewModel?.tab.tabType == .preferences {
            showPreferencesPage()
        } else if url != nil && url != URL.emptyPage {
            showWebView()
        } else {
            showHomepage()
        }
    }

    private func showWebView() {
        self.homepageView.removeFromSuperview()
        removePreferencesPage()

        if let webView = self.webView {
            addWebViewToViewHierarchy(webView)
        }
    }

    private func showHomepage() {
        self.webView?.removeFromSuperview()
        removePreferencesPage()

        view.addAndLayout(homepageView)
    }

    private func addWebViewToViewHierarchy(_ webView: WebView) {
        // This code should ideally use Auto Layout, but in order to enable the web inspector, it needs to use springs & structs.
        // The line at the bottom of this comment is the "correct" method of doing this, but breaks the inspector.
        // Context: https://stackoverflow.com/questions/60727065/wkwebview-web-inspector-in-macos-app-fails-to-render-and-flickers-flashes
        //
        // view.addAndLayout(newWebView)

        webView.frame = view.bounds
        webView.autoresizingMask = [.width, .height]
        view.addSubview(webView)
        setFirstResponderIfNeeded()
    }

    private func changeWebView() {

        func displayWebView(of tabViewModel: TabViewModel) {
            tabViewModel.tab.delegate = self

            let newWebView = tabViewModel.tab.webView
            newWebView.uiDelegate = self
            webView = newWebView

            addWebViewToViewHierarchy(newWebView)
        }

        func removeOldWebView(_ oldWebView: WebView?) {
            if let oldWebView = oldWebView, view.subviews.contains(oldWebView) {
                oldWebView.removeFromSuperview()
            }
        }

        guard let tabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            self.tabViewModel = nil
            removeOldWebView(webView)
            return
        }

        guard self.tabViewModel !== tabViewModel else { return }

        let oldWebView = webView
        displayWebView(of: tabViewModel)
        subscribeToUrl(of: tabViewModel)
        self.tabViewModel = tabViewModel
        removeOldWebView(oldWebView)
    }

    func subscribeToUrl(of tabViewModel: TabViewModel) {
         urlCancellable?.cancel()
         urlCancellable = tabViewModel.tab.$url.receive(on: DispatchQueue.main).sink { [weak self] url in
            self?.updateInterface(url: url)
         }
    }

    private func subscribeToIsErrorViewVisible() {
        isErrorViewVisibleCancellable = tabViewModel?.$isErrorViewVisible.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.displayErrorView(self?.tabViewModel?.isErrorViewVisible ?? false)
        }
    }

    private func setFirstResponderIfNeeded() {
        guard webView?.url != nil else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.webView?.makeMeFirstResponder()
        }
    }

    private func displayErrorView(_ shown: Bool) {
        guard let webView = webView else {
            os_log("BrowserTabViewController: Web view is nil", type: .error)
            return
        }

        errorView.isHidden = !shown
        webView.isHidden = shown
        homepageView.isHidden = shown
    }

    private func openNewTab(with url: URL?, parentTab: Tab?, selected: Bool = false) {
        let tab = Tab(url: url, parentTab: parentTab, shouldLoadInBackground: true)
        tabCollectionViewModel.append(tab: tab, selected: selected)
    }

    // MARK: - Preferences

    private lazy var preferencesViewController = PreferencesSplitViewController.create()

    private func showPreferencesPage() {
        self.webView?.removeFromSuperview()

        removePreferencesPage()

        self.addChild(preferencesViewController)
        view.addAndLayout(preferencesViewController.view)
    }

    private func removePreferencesPage() {
        preferencesViewController.removeFromParent()
        preferencesViewController.view.removeFromSuperview()
    }

}

extension BrowserTabViewController: TabDelegate {

	func tab(_ tab: Tab, requestedOpenExternalURL url: URL, forUserEnteredURL userEntered: Bool) {
        guard let window = self.view.window else {
            os_log("%s: Window is nil", type: .error, className)
            return
        }

        guard tabCollectionViewModel.selectedTabViewModel?.tab == tab else {
            // Only allow the selected tab to open external apps
            return
        }

		func searchForExternalUrl() {
			tab.update(url: URL.makeSearchUrl(from: url.absoluteString), userEntered: false)
		}

        guard let appUrl = NSWorkspace.shared.urlForApplication(toOpen: url) else {
			if userEntered {
				searchForExternalUrl()
			} else {
				NSAlert.unableToOpenExernalURLAlert().beginSheetModal(for: window)
			}
            return
        }

        let externalAppName = Bundle(url: appUrl)?.infoDictionary?["CFBundleName"] as? String
        NSAlert.openExternalURLAlert(with: externalAppName).beginSheetModal(for: window) { response in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                NSWorkspace.shared.open(url)
			} else if userEntered {
				searchForExternalUrl()
			}
        }
    }

    func tabPageDOMLoaded(_ tab: Tab) {
        if tabViewModel?.tab == tab {
            tabViewModel?.isLoading = false
        }
    }

    func tabDidStartNavigation(_ tab: Tab) {
        setFirstResponderIfNeeded()
        guard let tabViewModel = tabViewModel else { return }

        tabViewModel.closeFindInPage()
        if !tabViewModel.isLoading,
           tabViewModel.tab.webView.isLoading {
            tabViewModel.isLoading = true
        }
    }

    func tab(_ tab: Tab, requestedNewTab url: URL?, selected: Bool) {
        openNewTab(with: url, parentTab: tab, selected: selected)
    }

    func closeTab(_ tab: Tab) {
        guard let index = tabCollectionViewModel.tabCollection.tabs.firstIndex(of: tab) else {

            return
        }
        tabCollectionViewModel.remove(at: index)
    }

    func tab(_ tab: Tab, willShowContextMenuAt position: NSPoint, image: URL?, link: URL?) {
        contextMenuImage = image
        contextMenuLink = link
        contextMenuExpected = true
    }

    func tab(_ tab: Tab, detectedLogin host: String) {
        guard let window = view.window,
              !FireproofDomains.shared.isAllowed(fireproofDomain: host),
              !PasswordManagerSettings().canPromptOnDomain(host)
              else {
            os_log("%s: Window is nil", type: .error, className)
            return
        }

        let alert = NSAlert.fireproofAlert(with: host.dropWWW())
        alert.beginSheetModal(for: window) { response in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                Pixel.fire(.fireproof(kind: .init(url: tab.url), suggested: .suggested))
                FireproofDomains.shared.addToAllowed(domain: host)
            }
        }

        Pixel.fire(.fireproofSuggested())
    }

}

extension BrowserTabViewController: FileDownloadManagerDelegate {

    func chooseDestination(suggestedFilename: String?, directoryURL: URL?, fileTypes: [UTType], callback: @escaping (URL?, UTType?) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        let savePanel = NSSavePanel.withFileTypeChooser(fileTypes: fileTypes, suggestedFilename: suggestedFilename, directoryURL: directoryURL)

        func completionHandler(_ result: NSApplication.ModalResponse) {
            guard case .OK = result else {
                callback(nil, nil)
                return
            }
            callback(savePanel.url, savePanel.selectedFileType)
        }

        if let window = self.view.window {
            savePanel.beginSheetModal(for: window, completionHandler: completionHandler)
        } else {
            completionHandler(savePanel.runModal())
        }
    }

    func fileIconFlyAnimationOriginalRect(for downloadTask: WebKitDownloadTask) -> NSRect? {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let window = self.view.window,
              let dockScreen = NSScreen.dockScreen
        else { return nil }

        // fly 64x64 icon from the center of Address Bar
        let size = view.bounds.size
        let rect = NSRect(x: size.width / 2 - 32, y: size.height / 2 - 32, width: 64, height: 64)
        let windowRect = view.convert(rect, to: nil)
        let globalRect = window.convertToScreen(windowRect)
        // to the Downloads folder in Dock (in DockScreen coordinates)
        let dockScreenRect = dockScreen.convert(globalRect)

        return dockScreenRect
    }

    func tab(_ tab: Tab, requestedSaveCredentials credentials: SecureVaultModels.WebsiteCredentials) {
        tabViewModel?.credentialsToSave = credentials
    }

}

extension BrowserTabViewController: NSMenuDelegate {

    func menuWillOpen(_ menu: NSMenu) {
        guard contextMenuExpected else {
            os_log("%s: Unexpected menuWillOpen", type: .error, className)
            contextMenuLink = nil
            contextMenuImage = nil
            return
        }
        contextMenuExpected = false
    }

}

extension BrowserTabViewController: LinkMenuItemSelectors {

    func openLinkInNewTab(_ sender: NSMenuItem) {
        guard let url = contextMenuLink else { return }
        openNewTab(with: url, parentTab: tabViewModel?.tab)
    }

    func openLinkInNewWindow(_ sender: NSMenuItem) {
        guard let url = contextMenuLink else { return }
        WindowsManager.openNewWindow(with: url)
    }

    func downloadLinkedFileAs(_ sender: NSMenuItem) {
        guard let tab = tabCollectionViewModel.selectedTabViewModel?.tab,
              let url = contextMenuLink else { return }

        tab.download(from: url)
    }

    func copyLink(_ sender: NSMenuItem) {
        guard let url = contextMenuLink as NSURL? else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.URL], owner: nil)
        url.write(to: pasteboard)
    }

}

extension BrowserTabViewController: ImageMenuItemSelectors {

    func openImageInNewTab(_ sender: NSMenuItem) {
        guard let url = contextMenuImage else { return }
        openNewTab(with: url, parentTab: tabViewModel?.tab)
    }

    func openImageInNewWindow(_ sender: NSMenuItem) {
        guard let url = contextMenuImage else { return }
        WindowsManager.openNewWindow(with: url)
    }

    func saveImageAs(_ sender: NSMenuItem) {
        guard let tab = tabCollectionViewModel.selectedTabViewModel?.tab,
              let url = contextMenuImage else { return }

        tab.download(from: url)
    }

    func copyImageAddress(_ sender: NSMenuItem) {
        guard let url = contextMenuImage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .URL)
    }

}

extension BrowserTabViewController: WKUIDelegate {

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {

        // Returned web view must be created with the specified configuration.
        tabCollectionViewModel.appendNewTabAfterSelected(with: configuration)
        guard let selectedViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return nil
        }
        // WebKit loads the request in the returned web view.
        return selectedViewModel.tab.webView
    }
    
    func webView(_ webView: WKWebView,
                 runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {

        guard let window = view.window else {
            os_log("%s: Window is nil", type: .error, className)
            completionHandler(nil)
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection

        openPanel.beginSheetModal(for: window) { response in
            if response == NSApplication.ModalResponse.OK {
                completionHandler(openPanel.urls)
            } else {
                completionHandler(nil)
            }
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {

        guard let window = view.window else {
            os_log("%s: Window is nil", type: .error, className)
            completionHandler()
            return
        }

        let alert = NSAlert.javascriptAlert(with: message)
        alert.beginSheetModal(for: window) { _ in
            completionHandler()
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {

        guard let window = view.window else {
            os_log("%s: Window is nil", type: .error, className)
            completionHandler(false)
            return
        }

        let alert = NSAlert.javascriptConfirmation(with: message)
        alert.beginSheetModal(for: window) { response in
            completionHandler(response == .alertFirstButtonReturn)
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {

        guard let window = view.window else {
            os_log("%s: Window is nil", type: .error, className)
            completionHandler(nil)
            return
        }

        let alert = NSAlert.javascriptTextInput(prompt: prompt, defaultText: defaultText)
        alert.beginSheetModal(for: window) { response in
            guard let textField = alert.accessoryView as? NSTextField else {
                os_log("BrowserTabViewController: Textfield not found in alert", type: .error)
                completionHandler(nil)
                return
            }
            let answer = response == .alertFirstButtonReturn ? textField.stringValue : nil
            completionHandler(answer)
        }
    }

    func webViewDidClose(_ webView: WKWebView) {
        guard let webView = webView as? WebView else {
            os_log("BrowserTabViewController: Unknown instance of WKWebView", type: .error)
            return
        }

        tabCollectionViewModel.remove(ownerOf: webView)
    }

}
