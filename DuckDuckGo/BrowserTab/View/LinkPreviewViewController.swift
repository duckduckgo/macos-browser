//
//  LinkPreviewViewController.swift
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

import Cocoa
import WebKit

protocol LinkPreviewViewControllerDelegate: class {

    func linkPreviewViewController(_ controller: LinkPreviewViewController, requestedNewTab url: URL?)

}

class LinkPreviewViewController: NSViewController, NSPopoverDelegate {

    static func create(for initialURL: URL, compact: Bool = false) -> LinkPreviewViewController {
        let storyboard = NSStoryboard(name: "BrowserTab", bundle: nil)

        return storyboard.instantiateController(identifier: "LinkPreviewViewController") { coder in
            return LinkPreviewViewController(coder: coder, initialURL: initialURL, compact: compact)
        }
    }

    weak var delegate: LinkPreviewViewControllerDelegate?

    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var webView: WKWebView! {
        didSet {
            webView.configuration.applyStandardConfiguration()
            webView.configuration.defaultWebpagePreferences.preferredContentMode = .mobile
            webView.allowsLinkPreview = false
        }
    }

    @IBOutlet weak var toolbarContainer: NSBox!
    @IBOutlet weak var toolbarTitleLabel: NSTextField!
    @IBOutlet weak var backButton: NSButton!
    @IBOutlet weak var forwardButton: NSButton!

    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!

    @IBOutlet weak var webViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var webViewHeightConstraint: NSLayoutConstraint!

    private let initialURL: URL
    private let compact: Bool

    private func createDetachedWindowController() -> LinkPreviewWindowController {
        let viewController = LinkPreviewViewController.create(for: self.initialURL, compact: true)
        let detachedWindowController = LinkPreviewWindowController()
        detachedWindowController.contentViewController = viewController

        return detachedWindowController
    }

    init?(coder: NSCoder, initialURL: URL, compact: Bool = false) {
        self.initialURL = initialURL
        self.compact = compact

        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("You must create this view controller with a domain.")
    }

    deinit {
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if compact {
            titleLabel.isHidden = true
            bottomConstraint.priority = .required

            webViewWidthConstraint.priority = .defaultLow
            webViewHeightConstraint.isActive = false
        }

        toolbarContainer.isHidden = !compact

        observe(webView: webView)
        webView.load(initialURL)
    }

    @IBAction func pinToScreen(_ sender: NSButton) {
        guard let popoverWindowFrame = self.view.window?.frame else { return }

        let controller = createDetachedWindowController()
        controller.window?.setFrame(popoverWindowFrame, display: false)
        controller.showWindow(self)

        presentingViewController?.dismiss(self)
    }

    @IBAction func openInNewTab(_ sender: NSButton) {
        delegate?.linkPreviewViewController(self, requestedNewTab: webView.url)
        presentingViewController?.dismiss(self)
    }

    func detachableWindow(for popover: NSPopover) -> NSWindow? {
        let controller = createDetachedWindowController()
        LinkPreviewWindowControllerManager.shared.register(controller)
        return controller.window
    }

    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return true
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        return true
    }

    // MARK: - WKWebView

    private func observe(webView: WKWebView) {
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else {
            return
        }

        let viewWindowController = self.view.window?.windowController as? LinkPreviewWindowController

        switch keyPath {
        case #keyPath(WKWebView.url), #keyPath(WKWebView.title), #keyPath(WKWebView.canGoBack), #keyPath(WKWebView.canGoForward):
            updateTitle()

            self.backButton.isEnabled = webView.canGoBack
            self.forwardButton.isEnabled = webView.canGoForward
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    private func updateTitle() {
        if webView?.title?.trimmingWhitespaces().isEmpty ?? true {
            titleLabel.stringValue = webView.url?.host?.drop(prefix: "www.") ?? ""
            toolbarTitleLabel.stringValue = webView.url?.host?.drop(prefix: "www.") ?? ""
            return
        }

        titleLabel.stringValue = webView.title ?? ""
        toolbarTitleLabel.stringValue = webView.title ?? ""
    }

    @IBAction func closeButtonClicked(_ sender: NSButton) {
        presentingViewController?.dismiss(self)
        view.window?.close()
    }

    @IBAction func backButtonClicked(_ sender: NSButton) {
        webView.goBack()
    }

    @IBAction func forwardButtonClicked(_ sender: NSButton) {
        webView.goForward()
    }

    @IBAction func refreshButtonClicked(_ sender: NSButton) {
        webView.reload()
    }
}
