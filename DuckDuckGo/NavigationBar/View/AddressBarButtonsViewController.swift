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

    @IBOutlet weak var privacyEntryPointButton: PrivacyEntryPointAddressBarButton!
    @IBOutlet weak var trackersAnimationView: TrackersAnimationView!
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
    private var trackerInfoCancellable: AnyCancellable?
    private var bookmarkListCancellable: AnyCancellable?
    private var trackersAnimationViewStatusCancellable: AnyCancellable?

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
        subscribeToTrackersAnimationViewStatus()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(showUndoFireproofingPopover(_:)),
                                               name: FireproofDomains.Constants.newFireproofDomainNotification,
                                               object: nil)
    }

    @IBAction func bookmarkButtonAction(_ sender: Any) {
        openBookmarkPopover(setFavorite: false, accessPoint: .button)
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

        if let host = selectedTabViewModel.tab.content.url?.host, FireproofDomains.shared.isFireproof(fireproofDomain: host) {
            let viewController = FireproofInfoViewController.create(for: host)
            present(viewController, asPopoverRelativeTo: button.frame, of: button.superview!, preferredEdge: .minY, behavior: .transient)
        }
    }

    func openBookmarkPopover(setFavorite: Bool, accessPoint: Pixel.Event.AccessPoint) {
        guard let bookmark = bookmarkForCurrentUrl(setFavorite: setFavorite, accessPoint: accessPoint) else {
            assertionFailure("Failed to get a bookmark for the popover")
            return
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
        let isURLNil = selectedTabViewModel.tab.content.url == nil
        let isDuckDuckGoUrl = selectedTabViewModel.tab.content.url?.isDuckDuckGoSearch ?? false

        // Privacy entry point button
        privacyEntryPointButton.isHidden = isSearchingMode || isTextFieldEditorFirstResponder || isDuckDuckGoUrl || isURLNil
        trackersAnimationView.isHidden = privacyEntryPointButton.isHidden
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

        updateFireproofedButton()
    }

    private func updateFireproofedButton() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        if let url = selectedTabViewModel.tab.content.url,
           url.showFireproofStatus,
           !privacyEntryPointButton.isHidden,
           !trackersAnimationView.isAnimating {
            fireproofedButtonDivider.isHidden = !FireproofDomains.shared.isFireproof(fireproofDomain: url.host ?? "")
            fireproofedButton.isHidden = !FireproofDomains.shared.isFireproof(fireproofDomain: url.host ?? "")
        } else {
            fireproofedButtonDivider.isHidden = true
            fireproofedButton.isHidden = true
        }
    }

    private func setupButtons() {
        bookmarkButton.position = .right
        privacyEntryPointButton.position = .left
        privacyEntryPointButton.contentTintColor = .privacyEnabledColor
        imageButton.applyFaviconStyle()
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.subscribeToUrl()
            self?.subscribeToTrackerInfo()
        }
    }

    private func subscribeToUrl() {
        urlCancellable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            updateBookmarkButtonImage()
            return
        }

        urlCancellable = selectedTabViewModel.tab.$content.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateBookmarkButtonImage()
        }
    }

    private func subscribeToTrackerInfo() {
        trackerInfoCancellable?.cancel()

        updatePrivacyViews(trackerInfo: tabCollectionViewModel.selectedTabViewModel?.tab.trackerInfo, animated: false)
        trackerInfoCancellable = tabCollectionViewModel.selectedTabViewModel?.tab.$trackerInfo
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] trackerInfo in
                self?.updatePrivacyViews(trackerInfo: trackerInfo, animated: true)
            }
    }

    private func subscribeToBookmarkList() {
        bookmarkListCancellable = bookmarkManager.listPublisher.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateBookmarkButtonImage()
        }
    }

    private func updateBookmarkButtonImage(isUrlBookmarked: Bool = false) {
        if let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url,
           isUrlBookmarked || bookmarkManager.isUrlBookmarked(url: url) {
            bookmarkButton.image = Self.bookmarkFilledImage
            bookmarkButton.contentTintColor = NSColor.bookmarkFilledTint
        } else {
            bookmarkButton.image = Self.bookmarkImage
            bookmarkButton.contentTintColor = nil
        }
    }

    private func updatePrivacyViews(trackerInfo: TrackerInfo?, animated: Bool) {
        guard let trackerInfo = trackerInfo,
              !trackerInfo.trackersBlocked.isEmpty else {
            privacyEntryPointButton.reset()
            trackersAnimationView.reset()
            return
        }

        // Animate only when the first tracker is blocked
        if trackerInfo.trackersBlocked.count == 1 && animated {
            privacyEntryPointButton.animate()
            trackersAnimationView.animate()
        } else {
            privacyEntryPointButton.setFinal()
        }
    }

    private func bookmarkForCurrentUrl(setFavorite: Bool, accessPoint: Pixel.Event.AccessPoint) -> Bookmark? {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel,
              let url = selectedTabViewModel.tab.content.url else {
            assertionFailure("No URL for bookmarking")
            return nil
        }

        if let bookmark = bookmarkManager.getBookmark(for: url) {
            if setFavorite {
                bookmark.isFavorite = true
                bookmarkManager.update(bookmark: bookmark)
            }

            return bookmark
        }

        let bookmark = bookmarkManager.makeBookmark(for: url,
                                                title: selectedTabViewModel.title,
                                                isFavorite: setFavorite)
        updateBookmarkButtonImage(isUrlBookmarked: bookmark != nil)

        Pixel.fire(.bookmark(isFavorite: setFavorite, fireproofed: .init(url: url), source: accessPoint))

        return bookmark
    }

    @objc private func showUndoFireproofingPopover(_ sender: Notification) {
        guard view.window?.isKeyWindow == true,
            let domain = sender.userInfo?[FireproofDomains.Constants.newFireproofDomainKey] as? String else { return }

        DispatchQueue.main.async {
            let viewController = UndoFireproofingViewController.create(for: domain)
            let frame = self.fireproofedButton.frame.insetFromLineOfDeath()

            self.present(viewController,
                         asPopoverRelativeTo: frame,
                         of: self.fireproofedButton.superview!,
                         preferredEdge: .minY,
                         behavior: .applicationDefined)
        }
    }

    func subscribeToTrackersAnimationViewStatus() {
        trackersAnimationViewStatusCancellable = trackersAnimationView.$isAnimating
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
            self?.updateFireproofedButton()
        }
    }

}
