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

class BrowserTabViewController: NSViewController {

    @IBOutlet weak var errorView: NSView!
    weak var webView: WebView?
    var tabViewModel: TabViewModel?

    private let tabCollectionViewModel: TabCollectionViewModel
    private var urlCancellable: AnyCancellable?
    private var selectedTabViewModelCancellable: AnyCancellable?
    private var isErrorViewVisibleCancellable: AnyCancellable?
    private var contextMenuLink: URL?
    private var contextMenuImage: URL?

    required init?(coder: NSCoder) {
        fatalError("BrowserTabViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        subscribeToSelectedTabViewModel()
        subscribeToIsErrorViewVisible()
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.changeWebView()
            self?.subscribeToIsErrorViewVisible()
        }
    }

    private func changeWebView() {

        func displayWebView(of tabViewModel: TabViewModel) {
            tabViewModel.tab.delegate = self

            let newWebView = tabViewModel.tab.webView
            newWebView.uiDelegate = self

            // This code should ideally use Auto Layout, but in order to enable the web inspector, it needs to use springs & structs.
            // The line at the bottom of this comment is the "correct" method of doing this, but breaks the inspector.
            // Context: https://stackoverflow.com/questions/60727065/wkwebview-web-inspector-in-macos-app-fails-to-render-and-flickers-flashes
            //
            // view.addAndLayout(newWebView)

            newWebView.frame = view.bounds
            newWebView.autoresizingMask = [.width, .height]
            view.addSubview(newWebView)

            webView = newWebView
            setFirstResponderIfNeeded()
        }

        func subscribeToUrl(of tabViewModel: TabViewModel) {
            urlCancellable?.cancel()
            urlCancellable = tabViewModel.tab.$url.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.reloadWebViewIfNeeded() }
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

    private func subscribeToIsErrorViewVisible() {
        isErrorViewVisibleCancellable = tabViewModel?.$isErrorViewVisible.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.displayErrorView(self?.tabViewModel?.isErrorViewVisible ?? false)
        }
    }

    private func reloadWebViewIfNeeded() {
        guard let webView = webView else {
            os_log("BrowserTabViewController: Web view is nil", type: .error)
            return
        }

        guard let tabViewModel = tabViewModel else {
            os_log("%s: Tab view model is nil", type: .error, className)
            return
        }

        if webView.url == tabViewModel.tab.url { return }

        if let url = tabViewModel.tab.url {
            webView.load(url)
        } else {
            webView.load(URL.emptyPage)
        }
    }

    private func setFirstResponderIfNeeded() {
        guard let url = webView?.url else {
            // Without this, in certain situations in dark mode the page will be white when there's no url
            webView?.setValue(false, forKey: "drawsBackground")
            return
        }
        
        webView?.setValue(true, forKey: "drawsBackground")

        if !url.isDuckDuckGoSearch {
            DispatchQueue.main.async { [weak self] in
                self?.webView?.makeMeFirstResponder()
            }
        }
    }

    private func displayErrorView(_ shown: Bool) {
        guard let webView = webView else {
            os_log("BrowserTabViewController: Web view is nil", type: .error)
            return
        }

        errorView.isHidden = !shown
        webView.isHidden = shown
    }

    private func openNewTab(with url: URL?, selected: Bool = false) {
        let tab = Tab()
        tab.url = url
        tabCollectionViewModel.append(tab: tab, selected: selected)
    }

}

extension BrowserTabViewController: TabDelegate {

    func tabDidStartNavigation(_ tab: Tab) {
        setFirstResponderIfNeeded()
        tabViewModel?.closeFindInPage()
    }

    func tab(_ tab: Tab, requestedNewTab url: URL?, selected: Bool) {
        openNewTab(with: url, selected: selected)
    }

    func tab(_ tab: Tab, requestedFileDownload download: FileDownload) {
        FileDownloadManager.shared.startDownload(download)

        // Note this can result in tabs being left open, e.g. download button on this page:
        // https://en.wikipedia.org/wiki/Guitar#/media/File:GuitareClassique5.png
        //  Safari closes new tabs that were opened and then create a download instantly.  Should we do the same?
    }

    func tab(_ tab: Tab, willShowContextMenuAt position: NSPoint, image: URL?, link: URL?) {
        contextMenuImage = image
        contextMenuLink = link
    }

    func tab(_ tab: Tab, detectedLogin host: String) {
        guard let window = view.window, !FireproofDomains.shared.isAllowed(fireproofDomain: host) else {
            os_log("%s: Window is nil", type: .error, className)
            return
        }

        let alert = NSAlert.fireproofAlert(with: host)
        alert.beginSheetModal(for: window) { response in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                FireproofDomains.shared.addToAllowed(domain: host)
            }
        }
    }

}

extension BrowserTabViewController: LinkMenuItemSelectors {

    func openLinkInNewTab(_ sender: NSMenuItem) {
        guard let url = contextMenuLink else { return }
        openNewTab(with: url)
    }

    func openLinkInNewWindow(_ sender: NSMenuItem) {
        guard let url = contextMenuLink else { return }
        WindowsManager.openNewWindow(with: url)
    }

    func downloadLinkedFile(_ sender: NSMenuItem) {
        guard let tab = tabCollectionViewModel.selectedTabViewModel?.tab,
              let url = contextMenuLink else { return }

        self.tab(tab, requestedFileDownload: FileDownload(request: URLRequest(url: url), suggestedName: nil))
    }

}

extension BrowserTabViewController: ImageMenuItemSelectors {

    func openImageInNewTab(_ sender: NSMenuItem) {
        guard let url = contextMenuImage else { return }
        openNewTab(with: url)
    }

    func openImageInNewWindow(_ sender: NSMenuItem) {
        guard let url = contextMenuImage else { return }
        WindowsManager.openNewWindow(with: url)
    }

    func saveImageToDownloads(_ sender: NSMenuItem) {
        guard let tab = tabCollectionViewModel.selectedTabViewModel?.tab,
              let url = contextMenuImage else { return }

        self.tab(tab, requestedFileDownload: FileDownload(request: URLRequest(url: url), suggestedName: nil))
    }

    func copyImageAddress(_ sender: NSMenuItem) {
        guard let url = contextMenuImage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .URL)
    }

}

extension BrowserTabViewController: WKUIDelegate {

    // swiftlint:disable identifier_name
    @objc func _webView(_ webView: WKWebView, saveDataToFile data: NSData, suggestedFilename: NSString, mimeType: NSString, originatingURL: NSURL) {
        FileDownloadManager.shared.saveDataToFile(data as Data, withSuggestedFileName: suggestedFilename as String, mimeType: mimeType as String)
    }
    // swiftlint:enable identifier_name

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

fileprivate extension NSAlert {

    static func javascriptAlert(with message: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: UserText.ok)
        return alert
    }

    static func javascriptConfirmation(with message: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: UserText.ok)
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func javascriptTextInput(prompt: String, defaultText: String?) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = prompt
        alert.addButton(withTitle: UserText.ok)
        alert.addButton(withTitle: UserText.cancel)
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = defaultText
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField
        return alert
    }

    static func fireproofAlert(with domain: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.fireproofConfirmationTitle(domain: domain)
        alert.informativeText = UserText.fireproofConfirmationMessage
        alert.alertStyle = .warning
        alert.icon = #imageLiteral(resourceName: "Fireproof")
        alert.addButton(withTitle: UserText.fireproof)
        alert.addButton(withTitle: UserText.notNow)
        return alert
    }

}
