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

// swiftlint:disable file_length
final class BrowserTabViewController: NSViewController {

    @IBOutlet weak var errorView: NSView!
    @IBOutlet weak var homepageView: NSView!
    @IBOutlet weak var errorMessageLabel: NSTextField!
    @IBOutlet weak var hoverLabel: NSTextField!
    @IBOutlet weak var hoverLabelContainer: NSView!
    weak var webView: WebView?

    var tabViewModel: TabViewModel?

    private let tabCollectionViewModel: TabCollectionViewModel
    private var urlCancellable: AnyCancellable?
    private var selectedTabViewModelCancellable: AnyCancellable?
    private var errorViewStateCancellable: AnyCancellable?

    private var contextMenuExpected = false
    private var contextMenuLink: URL?
    private var contextMenuImage: URL?
    private var contextMenuSelectedText: String?

    private var hoverLabelWorkItem: DispatchWorkItem?

    private var temporaryContentController: NSViewController?

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

        hoverLabelContainer.alphaValue = 0
        subscribeToSelectedTabViewModel()
        subscribeToErrorViewState()
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel
            .sink { [weak self] selectedTabViewModel in
                self?.updateInterface(tabViewModel: selectedTabViewModel)
                self?.subscribeToErrorViewState()
        }
    }

    /// Takes a URL and decided what to do with the UI. There are three states:
    ///
    /// 1. No URL is provided, so the webview should be hidden in favor of showing the default UI elements.
    /// 2. A URL is provided for the first time, so the webview should be added as a subview and the URL should be loaded.
    /// 3. A URL is provided after already adding the webview, so the webview should be reloaded.
    private func updateInterface(tabViewModel: TabViewModel?) {
        if tabCollectionViewModel.tabCollection.tabs.isEmpty {
            view.window?.close()
            return
        }

        changeWebView(tabViewModel: tabViewModel)
        scheduleHoverLabelUpdatesForUrl(nil)
        show(tabContent: tabViewModel?.tab.content)
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

        // Make sure this is on top
        view.addSubview(hoverLabelContainer)
    }

    private func changeWebView(tabViewModel: TabViewModel?) {

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

        guard let tabViewModel = tabViewModel else {
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
         urlCancellable = tabViewModel.tab.$content
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateInterface(tabViewModel: tabViewModel)
         }
    }

    private func subscribeToErrorViewState() {
        errorViewStateCancellable = tabViewModel?.$errorViewState.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.displayErrorView(
                self?.tabViewModel?.errorViewState.isVisible ?? false,
                message: self?.tabViewModel?.errorViewState.message ?? UserText.unknownErrorMessage
            )
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

    private func displayErrorView(_ shown: Bool, message: String) {
        guard let webView = webView else {
            os_log("BrowserTabViewController: Web view is nil", type: .error)
            return
        }

        errorMessageLabel.stringValue = message
        errorView.isHidden = !shown
        webView.isHidden = shown
        homepageView.isHidden = shown
    }

    func openNewTab(with content: Tab.TabContent, parentTab: Tab? = nil, selected: Bool = false, canBeClosedWithBack: Bool = false) {
        // shouldn't open New Tabs in PopUp window
        guard view.window?.isPopUpWindow == false else {
            // Prefer Tab's Parent
            if let parentTab = tabCollectionViewModel.selectedTabViewModel?.tab.parentTab, parentTab.delegate !== self {
                parentTab.delegate?.tab(parentTab, requestedNewTabWith: content, selected: true)
                parentTab.webView.window?.makeKeyAndOrderFront(nil)
            // Act as default URL Handler if no Parent
            } else {
                WindowControllersManager.shared.showTab(with: content)
            }
            return
        }

        let tab = Tab(content: content,
                      parentTab: parentTab,
                      shouldLoadInBackground: true,
                      canBeClosedWithBack: canBeClosedWithBack)

        if parentTab != nil {
            tabCollectionViewModel.insertChild(tab: tab, selected: selected)
        } else {
            tabCollectionViewModel.append(tab: tab, selected: selected)
        }
    }

    // MARK: - Browser Tabs

    private func show(displayableTabAtIndex index: Int) {
        // The tab switcher only displays displayable tab types.
        tabCollectionViewModel.selectedTabViewModel?.tab.setContent(Tab.TabContent.displayableTabTypes[index])
        updateInterface(tabViewModel: tabCollectionViewModel.selectedTabViewModel)
    }

    private func removeAllTabContent(includingWebView: Bool = true) {
        self.homepageView.removeFromSuperview()
        temporaryContentController?.removeCompletely()
        preferencesViewController.removeCompletely()
        bookmarksViewController.removeCompletely()
        if includingWebView {
            self.webView?.removeFromSuperview()
        }
    }

    private func showTabContentController(_ vc: NSViewController) {
        self.addChild(vc)
        view.addAndLayout(vc.view)
    }

    private func showTemporaryTabContentController(_ vc: NSViewController) {
        temporaryContentController?.removeCompletely()
        showTabContentController(vc)
        temporaryContentController = vc
    }

    private func requestDisableUI() {
        (view.window?.windowController as? MainWindowController)?.userInteraction(prevented: true)
    }

    private func show(tabContent content: Tab.TabContent?) {

        switch content ?? .homepage {
        case .bookmarks:
            removeAllTabContent()
            showTabContentController(bookmarksViewController)

        case .preferences:
            removeAllTabContent()
            showTabContentController(preferencesViewController)

        case .onboarding:
            removeAllTabContent()
            requestDisableUI()
            showTemporaryTabContentController(OnboardingViewController.create(withDelegate: self))

        case .url:
            removeAllTabContent(includingWebView: false)
            if let webView = self.webView, webView.superview == nil {
                addWebViewToViewHierarchy(webView)
            }

        case .homepage:
            removeAllTabContent()
            view.addAndLayout(homepageView)

        case .none:
            removeAllTabContent()
        }
        
    }

    // MARK: - Preferences

    private(set) lazy var preferencesViewController: PreferencesSplitViewController = {
        let viewController = PreferencesSplitViewController.create()
        viewController.delegate = self

        return viewController
    }()

    // MARK: - Bookmarks

    private(set) lazy var bookmarksViewController: BookmarkManagementSplitViewController = {
        let viewController = BookmarkManagementSplitViewController.create()
        viewController.delegate = self

        return viewController
    }()

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
        tabViewModel.tab.resetDashboardInfo(tabViewModel.tab.webView.url)
        tab.permissions.tabDidStartNavigation()
        if !tabViewModel.isLoading,
           tabViewModel.tab.webView.isLoading {
            tabViewModel.isLoading = true
        }
    }

    func tab(_ tab: Tab, requestedNewTabWith content: Tab.TabContent, selected: Bool) {
        openNewTab(with: content, parentTab: tab, selected: selected, canBeClosedWithBack: selected == true)
    }

    func closeTab(_ tab: Tab) {
        guard let index = tabCollectionViewModel.tabCollection.tabs.firstIndex(of: tab) else {

            return
        }
        tabCollectionViewModel.remove(at: index)
    }

    func tab(_ tab: Tab,
             willShowContextMenuAt position: NSPoint,
             image: URL?,
             link: URL?,
             selectedText: String?) {
        contextMenuImage = image
        contextMenuLink = link
        contextMenuExpected = true
        contextMenuSelectedText = selectedText
    }

    func tab(_ tab: Tab,
             requestedBasicAuthenticationChallengeWith protectionSpace: URLProtectionSpace,
             completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let window = view.window else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let alert = AuthenticationAlert(host: protectionSpace.host, isEncrypted: protectionSpace.receivesCredentialSecurely)
        alert.beginSheetModal(for: window) { response in
            guard case .OK = response,
                  !alert.usernameTextField.stringValue.isEmpty,
                  !alert.passwordTextField.stringValue.isEmpty
            else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            completionHandler(.useCredential, URLCredential(user: alert.usernameTextField.stringValue,
                                                            password: alert.passwordTextField.stringValue,
                                                            persistence: .none))

        }
    }

    func tab(_ tab: Tab, didChangeHoverLink url: URL?) {
        scheduleHoverLabelUpdatesForUrl(url)
    }

    func windowDidResignKey() {
        scheduleHoverLabelUpdatesForUrl(nil)
    }

    private func scheduleHoverLabelUpdatesForUrl(_ url: URL?) {
        // cancel previous animation, if any
        hoverLabelWorkItem?.cancel()

        // schedule an animation if needed
        var animationItem: DispatchWorkItem?
        var delay: Double = 0
        if url == nil && hoverLabelContainer.alphaValue > 0 {
            // schedule a fade out
            delay = 0.1
            animationItem = DispatchWorkItem { [weak self] in
                self?.hoverLabelContainer.animator().alphaValue = 0
            }
        } else if url != nil && hoverLabelContainer.alphaValue < 1 {
            // schedule a fade in
            delay = 0.5
            animationItem = DispatchWorkItem { [weak self] in
                self?.hoverLabel.stringValue = url?.absoluteString ?? ""
                self?.hoverLabelContainer.animator().alphaValue = 1
            }
        } else {
            hoverLabel.stringValue = url?.absoluteString ?? ""
        }

        if let item = animationItem {
            hoverLabelWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

}

extension BrowserTabViewController: FileDownloadManagerDelegate {

    func chooseDestination(suggestedFilename: String?, directoryURL: URL?, fileTypes: [UTType], callback: @escaping (URL?, UTType?) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))

        var fileTypes = fileTypes
        if fileTypes.isEmpty || (fileTypes.count == 1 && (fileTypes[0].fileExtension?.isEmpty ?? true)),
           let fileExt = (suggestedFilename as NSString?)?.pathExtension,
           let utType = UTType(fileExtension: fileExt) {
            // When no file extension is set by default generate fileType from file extension
            fileTypes.insert(utType, at: 0)
        }
        // allow user set any file extension
        if fileTypes.count == 1 && !fileTypes.contains(where: { $0.fileExtension?.isEmpty ?? true }) {
            fileTypes.append(.data)
        }

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
        guard PasswordManagerSettings().canPromptOnDomain(credentials.account.domain) else { return }
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
        openNewTab(with: .url(url), parentTab: tabViewModel?.tab)
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
        pasteboard.setString(url.absoluteString ?? "", forType: .string)
    }

}

extension BrowserTabViewController: ImageMenuItemSelectors {

    func openImageInNewTab(_ sender: NSMenuItem) {
        guard let url = contextMenuImage else { return }
        openNewTab(with: .url(url), parentTab: tabViewModel?.tab)
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
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        NSPasteboard.general.setString(url.absoluteString, forType: .URL)
    }

}

extension BrowserTabViewController: MenuItemSelectors {

    func search(_ sender: NSMenuItem) {
        let selectedText = contextMenuSelectedText ?? ""
        guard let url = URL.makeSearchUrl(from: selectedText) else { return }
        openNewTab(with: .url(url), parentTab: tabViewModel?.tab, selected: true)
    }

}

extension BrowserTabViewController: WKUIDelegate {

    @objc(_webView:saveDataToFile:suggestedFilename:mimeType:originatingURL:)
    func webView(_ webView: WKWebView, saveDataToFile data: Data, suggestedFilename: String, mimeType: String, originatingURL: URL) {
        func write(to url: URL) throws {
            let progress = Progress(totalUnitCount: 1,
                                    fileOperationKind: .downloading,
                                    kind: .file,
                                    isPausable: false,
                                    isCancellable: false,
                                    fileURL: url)
            progress.publish()
            defer {
                progress.unpublish()
            }

            try data.write(to: url)
            progress.completedUnitCount = progress.totalUnitCount
        }

        let prefs = DownloadPreferences()
        if !prefs.alwaysRequestDownloadLocation,
           let location = prefs.selectedDownloadLocation {
            let url = location.appendingPathComponent(suggestedFilename)
            try? write(to: url)

            return
        }

        chooseDestination(suggestedFilename: suggestedFilename,
                          directoryURL: prefs.selectedDownloadLocation,
                          fileTypes: UTType(mimeType: mimeType).map { [$0] } ?? []) { url, _ in
            guard let url = url else { return }
            try? write(to: url)
        }
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {

        func makeTab(parentTab: Tab, content: Tab.TabContent) -> Tab {
            // Returned web view must be created with the specified configuration.
            return Tab(content: content,
                       webViewConfiguration: configuration,
                       parentTab: parentTab,
                       canBeClosedWithBack: true)
        }
        guard let parentTab = webView.tab else { return nil }
        func nextQuery(parentTab: Tab) -> PermissionAuthorizationQuery? {
            parentTab.permissions.authorizationQueries.first(where: { $0.permissions.contains(.popups) })
        }

        var shouldOpenPopUp = navigationAction.isUserInitiated
        if !shouldOpenPopUp {
            let url = navigationAction.request.url
            parentTab.permissions.permissions([.popups],
                                              requestedForDomain: navigationAction.sourceFrame.request.url?.host,
                                              url: url) { [weak parentTab] granted in

                guard let parentTab = parentTab else { return }

                switch (granted, shouldOpenPopUp) {
                case (true, false):
                    // callback called synchronously - will return webView for the request
                    shouldOpenPopUp = true
                case (true, true):
                    // called asynchronously
                    guard let url = navigationAction.request.url else { return }
                    let tab = makeTab(parentTab: parentTab, content: .url(url))
                    WindowsManager.openPopUpWindow(with: tab)

                    parentTab.permissions.permissions.popups.popupOpened(nextQuery: nextQuery(parentTab: parentTab))

                case (false, _):
                    return
                }
            }
        }
        guard shouldOpenPopUp else {
            shouldOpenPopUp = true // if granted asynchronously
            return nil
        }

        let tab = makeTab(parentTab: parentTab, content: .none)
        if windowFeatures.toolbarsVisibility?.boolValue == true {
            tabCollectionViewModel.insertChild(tab: tab, selected: true)
        } else {
            WindowsManager.openPopUpWindow(with: tab)
        }
        parentTab.permissions.permissions.popups.popupOpened(nextQuery: nextQuery(parentTab: parentTab))

        // WebKit loads the request in the returned web view.
        return tab.webView
    }

    @objc(_webView:checkUserMediaPermissionForURL:mainFrameURL:frameIdentifier:decisionHandler:)
    func webView(_ webView: WKWebView,
                 checkUserMediaPermissionFor url: URL,
                 mainFrameURL: URL,
                 frameIdentifier frame: UInt,
                 decisionHandler: @escaping (String, Bool) -> Void) {
        webView.tab?.permissions.checkUserMediaPermission(for: url, mainFrameURL: mainFrameURL, decisionHandler: decisionHandler)
            ?? /* Tab deallocated: */ {
                decisionHandler("", false)
            }()
    }

    // https://github.com/WebKit/WebKit/blob/995f6b1595611c934e742a4f3a9af2e678bc6b8d/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegate.h#L147
    @objc(webView:requestMediaCapturePermissionForOrigin:initiatedByFrame:type:decisionHandler:)
    @available(macOS 12, *)
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        guard let permissions = [PermissionType](devices: type) else {
            assertionFailure("Could not decode PermissionType")
            decisionHandler(.deny)
            return
        }

        webView.tab?.permissions.permissions(permissions, requestedForDomain: origin.host) { granted in
            decisionHandler(granted ? .grant : .deny)
        } ?? /* Tab deallocated: */ {
            decisionHandler(.deny)
        }()
    }

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L126
    @objc(_webView:requestUserMediaAuthorizationForDevices:url:mainFrameURL:decisionHandler:)
    func webView(_ webView: WKWebView,
                 requestUserMediaAuthorizationFor devices: _WKCaptureDevices,
                 url: URL,
                 mainFrameURL: URL,
                 decisionHandler: @escaping (Bool) -> Void) {
        guard let permissions = [PermissionType](devices: devices) else {
            decisionHandler(false)
            return
        }

        webView.tab?.permissions.permissions(permissions, requestedForDomain: url.host, decisionHandler: decisionHandler)
            ?? /* Tab deallocated: */ {
                decisionHandler(false)
            }()
    }

    @objc(_webView:mediaCaptureStateDidChange:)
    func webView(_ webView: WKWebView, mediaCaptureStateDidChange state: _WKMediaCaptureStateDeprecated) {
        webView.tab?.permissions.mediaCaptureStateDidChange()
    }

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L131
    @objc(_webView:requestGeolocationPermissionForFrame:decisionHandler:)
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor frame: WKFrameInfo, decisionHandler: @escaping (Bool) -> Void) {
        webView.tab?.permissions.permissions([.geolocation], requestedForDomain: frame.request.url?.host, decisionHandler: decisionHandler)
            ?? /* Tab deallocated: */ {
                decisionHandler(false)
            }()
    }

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L132
    @objc(_webView:requestGeolocationPermissionForOrigin:initiatedByFrame:decisionHandler:)
    @available(macOS 12, *)
    func webView(_ webView: WKWebView,
                 requestGeolocationPermissionFor origin: WKSecurityOrigin,
                 initiatedBy frame: WKFrameInfo,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        webView.tab?.permissions.permissions([.geolocation], requestedForDomain: frame.request.url?.host) { granted in
            decisionHandler(granted ? .grant : .deny)
        } ?? /* Tab deallocated: */ {
            decisionHandler(.deny)
        }()
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

extension BrowserTabViewController: BrowserTabSelectionDelegate {

    func selectedTab(at index: Int) {
        show(displayableTabAtIndex: index)
    }

}

private extension WKWebView {

    var tab: Tab? {
        guard let navigationDelegate = self.navigationDelegate else { return nil }
        guard let tab = navigationDelegate as? Tab else {
            assertionFailure("webView.navigationDelegate is not a Tab")
            return nil
        }
        return tab
    }

}

extension BrowserTabViewController: OnboardingDelegate {

    func onboardingDidRequestImportData(completion: @escaping () -> Void) {
        print(#function)

        let viewController = DataImportViewController.create()
        beginSheet(viewController) { _ in
            completion()
        }
    }

    func onboardingDidRequestSetDefault(completion: @escaping () -> Void) {
        print(#function)
        DefaultBrowserPreferences.becomeDefault()

        var observer: Any?
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            completion()
            NotificationCenter.default.removeObserver(observer as Any)
        }
    }

    func onboardingHasFinished() {
        print(#function)
        (view.window?.windowController as? MainWindowController)?.userInteraction(prevented: false)
    }

}

// swiftlint:enable file_length
