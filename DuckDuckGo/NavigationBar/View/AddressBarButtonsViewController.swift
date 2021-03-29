//
//  AddressBarButtonsViewController.swift
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
import Combine
import os.log

protocol AddressBarButtonsViewControllerDelegate: AnyObject {

    func addressBarButtonsViewControllerClearButtonClicked(_ addressBarButtonsViewController: AddressBarButtonsViewController)

}

final class AddressBarButtonsViewController: NSViewController {

    static let homeFaviconImage = NSImage(named: "HomeFavicon")
    static let webImage = NSImage(named: "Web")
    static let bookmarkImage = NSImage(named: "Bookmark")
    static let bookmarkFilledImage = NSImage(named: "BookmarkFilled")

    weak var delegate: AddressBarButtonsViewControllerDelegate?

    private lazy var bookmarkPopover = BookmarkPopover()

    @IBOutlet weak var privacyEntryPointButton: AddressBarButton!
    @IBOutlet weak var bookmarkButton: AddressBarButton!
    @IBOutlet weak var imageButtonWrapper: NSView!
    @IBOutlet weak var imageButton: NSButton!
    @IBOutlet weak var clearButton: NSButton!

    @IBOutlet weak var fireproofedButtonDivider: NSBox! {
        didSet {
            fireproofedButtonDivider.isHidden = true
        }
    }

    @IBOutlet weak var fireproofedButton: NSButton! {
        didSet {
            fireproofedButton.isHidden = true
            fireproofedButton.target = self
            fireproofedButton.action = #selector(fireproofedButtonAction)
        }
    }

    private var tabCollectionViewModel: TabCollectionViewModel
    private var bookmarkManager: BookmarkManager = LocalBookmarkManager.shared

    private var selectedTabViewModelCancellable: AnyCancellable?
    private var urlCancellable: AnyCancellable?
    private var bookmarkListCancellable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("AddressBarButtonsViewController: Bad initializer")
    }

    init?(coder: NSCoder,
          tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupButtons()
        subscribeToSelectedTabViewModel()
        subscribeToBookmarkList()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(showUndoFireproofingPopover(_:)),
                                               name: FireproofDomains.Constants.newFireproofDomainNotification,
                                               object: nil)
    }

    @IBAction func bookmarkButtonAction(_ sender: Any) {
        openBookmarkPopover(setFavorite: false)
    }

    @IBAction func clearButtonAction(_ sender: Any) {
        delegate?.addressBarButtonsViewControllerClearButtonClicked(self)
    }
    
    @IBAction func privacyEntryPointButtonAction(_ sender: Any) {
        privacyEntryPointButton.state = .off
    }

    @objc func fireproofedButtonAction(_ sender: Any) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel, let button = sender as? NSButton else {
            return
        }

        if let host = selectedTabViewModel.tab.url?.host, FireproofDomains.shared.isAllowed(fireproofDomain: host) {
            let viewController = FireproofInfoViewController.create(for: host)
            present(viewController, asPopoverRelativeTo: button.frame, of: button.superview!, preferredEdge: .minY, behavior: .transient)
        }
    }

    func openBookmarkPopover(setFavorite: Bool) {
        guard var bookmark = bookmarkForCurrentUrl() else {
            assertionFailure("Failed to get a bookmark for the popover")
            return
        }

        if setFavorite {
            bookmark.isFavorite = true
            bookmarkManager.update(bookmark: bookmark)
        }

        if !bookmarkPopover.isShown {
            bookmarkPopover.viewController.bookmark = bookmark
            bookmarkPopover.show(relativeTo: bookmarkButton.bounds, of: bookmarkButton, preferredEdge: .maxY)
        } else {
            bookmarkPopover.close()
        }
    }

    func updateButtons(mode: AddressBarViewController.Mode,
                       isTextFieldEditorFirstResponder: Bool,
                       textFieldValue: AddressBarTextField.Value) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        let isSearchingMode = mode != .browsing
        let isURLNil = selectedTabViewModel.tab.url == nil
        let isDuckDuckGoUrl = selectedTabViewModel.tab.url?.isDuckDuckGoSearch ?? false

        // Privacy entry point button
        privacyEntryPointButton.isHidden = isSearchingMode || isTextFieldEditorFirstResponder || isDuckDuckGoUrl || isURLNil
        imageButtonWrapper.isHidden = !privacyEntryPointButton.isHidden

        clearButton.isHidden = !(isTextFieldEditorFirstResponder && !textFieldValue.isEmpty)
        bookmarkButton.isHidden = !clearButton.isHidden || textFieldValue.isEmpty

        // Image button
        switch mode {
        case .browsing:
            imageButton.image = selectedTabViewModel.favicon
        case .searching(withUrl: true):
            imageButton.image = Self.webImage
        case .searching(withUrl: false):
            imageButton.image = Self.homeFaviconImage
        }

        // Fireproof button
        if let url = selectedTabViewModel.tab.url, url.showFireproofStatus, !privacyEntryPointButton.isHidden {
            fireproofedButtonDivider.isHidden = !FireproofDomains.shared.isAllowed(fireproofDomain: url.host ?? "")
            fireproofedButton.isHidden = !FireproofDomains.shared.isAllowed(fireproofDomain: url.host ?? "")
        } else {
            fireproofedButtonDivider.isHidden = true
            fireproofedButton.isHidden = true
        }
    }

    private func setupButtons() {
        bookmarkButton.position = .right
        privacyEntryPointButton.position = .left
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.subscribeToUrl()
        }
    }

    private func subscribeToUrl() {
        urlCancellable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            updateBookmarkButtonImage()
            return
        }

        urlCancellable = selectedTabViewModel.tab.$url.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateBookmarkButtonImage()
        }
    }

    private func subscribeToBookmarkList() {
        bookmarkListCancellable = bookmarkManager.listPublisher.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateBookmarkButtonImage()
        }
    }

    private func updateBookmarkButtonImage(isUrlBookmarked: Bool = false) {
        if let url = tabCollectionViewModel.selectedTabViewModel?.tab.url,
           isUrlBookmarked || bookmarkManager.isUrlBookmarked(url: url) {
            bookmarkButton.image = Self.bookmarkFilledImage
        } else {
            bookmarkButton.image = Self.bookmarkImage
        }
    }

    private func bookmarkForCurrentUrl() -> Bookmark? {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel,
              let url = selectedTabViewModel.tab.url else {
            assertionFailure("No URL for bookmarking")
            return nil
        }

        var bookmark = bookmarkManager.getBookmark(for: url)
        if bookmark == nil {
            bookmark = bookmarkManager.makeBookmark(for: url,
                                                    title: selectedTabViewModel.title,
                                                    isFavorite: false)
            updateBookmarkButtonImage(isUrlBookmarked: bookmark != nil)
        }
        return bookmark
    }

    @objc private func showUndoFireproofingPopover(_ sender: Notification) {
        guard let domain = sender.userInfo?[FireproofDomains.Constants.newFireproofDomainKey] as? String else { return }

        DispatchQueue.main.async {
            let viewController = UndoFireproofingViewController.create(for: domain)
            let frame = self.fireproofedButton.frame.insetBy(dx: -10, dy: -10)

            self.present(viewController,
                         asPopoverRelativeTo: frame,
                         of: self.fireproofedButton.superview!,
                         preferredEdge: .minY,
                         behavior: .transient)
        }
    }

}
