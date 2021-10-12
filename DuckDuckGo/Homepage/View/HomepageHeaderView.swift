//
//  HomepageHeaderView.swift
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
import Combine

final class HomepageHeaderView: NSView {

    enum Mode: Equatable {
        case idle
        case domain
        case search
    }

    static let homeFaviconImage = NSImage(named: "HomeFavicon")
    static let homeSearchImage = NSImage(named: "Search")
    static let webImage = NSImage(named: "Web")

    static let modeImages = [
        Mode.idle: homeSearchImage,
        Mode.domain: webImage,
        Mode.search: homeFaviconImage
    ]

    private var mode: Mode = .idle {
        didSet {
            updateTextFieldIcon()
            updateSearchView()
        }
    }

    var tabViewCollectionModel: TabCollectionViewModel? {
        didSet {
            field.tabCollectionViewModel = tabViewCollectionModel
        }
    }

    private let suggestionContainerViewModel = SuggestionContainerViewModel(suggestionContainer: SuggestionContainer())

    @IBOutlet weak var backgroundView: NSView!
    @IBOutlet weak var container: MouseClickView!
    @IBOutlet weak var field: AddressBarTextField!
    @IBOutlet weak var shadowView: ShadowView!
    @IBOutlet weak var icon: NSImageView!
    @IBOutlet weak var backgroundHeight: NSLayoutConstraint!

    private var fieldCancellable: AnyCancellable?
    private var suggestionsCancellable: AnyCancellable?

    override func awakeFromNib() {
        super.awakeFromNib()

        wantsLayer = true
        layer?.masksToBounds = false
        
        shadowView.shadowColor = .suggestionsShadowColor
        shadowView.shadowRadius = 8.0

        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 8
        backgroundView.layer?.backgroundColor = NSColor.addressBarBackgroundColor.cgColor
        backgroundView.layer?.borderColor = NSColor.addressBarBorderColor.cgColor
        backgroundView.layer?.borderWidth = 1

        container.delegate = self

        field.suggestionContainerViewModel = suggestionContainerViewModel

        subscribeToField()
        updateTextFieldIcon()
    }

    private func subscribeToField() {
        fieldCancellable = field.$value.receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self = self else { return }
            self.updateMode()
        }

        suggestionsCancellable = field.suggestionWindowVisible.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSearchView()
            }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(textFieldFirstReponderNotification(_:)),
                                               name: .firstResponder,
                                               object: nil)

    }

    private func updateMode() {
        switch self.field.value {
        case .text(let text): self.mode = text.isEmpty ? .idle : .search
        case .url(urlString: _, url: _, userTyped: let userTyped): self.mode = userTyped ? .domain : .search
        case .suggestion(let suggestionViewModel):
            switch suggestionViewModel.suggestion {
            case .phrase, .unknown: self.mode = .search
            case .website, .bookmark, .historyEntry: self.mode = .domain
            }
        }
    }

    private func updateTextFieldIcon() {
        icon.image = Self.modeImages[mode, default: Self.homeSearchImage]
    }

    private func showSearchInactive() {
        print(#function)
        backgroundHeight.constant = 42
        shadowView.isHidden = true
    }

    private func showSearchActive() {
        print(#function)
        backgroundHeight.constant = 42
        shadowView.isHidden = false
        shadowView.shadowSides = .all
    }

    private func showSearchHasResults() {
        print(#function)
        backgroundHeight.constant = 60
        shadowView.isHidden = false
        shadowView.shadowSides = [.left, .top, .right]
    }

    private func updateSearchView() {
        if window?.firstResponder != field.currentEditor() {
           showSearchInactive()
        } else if field.isSuggestionWindowVisible {
            showSearchHasResults()
        } else {
            showSearchActive()
        }
    }

    @objc func textFieldFirstReponderNotification(_ notification: Notification) {
        if mode != .idle {
            self.mode = .idle
        }
        updateSearchView()
    }

}

extension HomepageHeaderView: MouseClickViewDelegate {

    func mouseClickView(_ mouseClickView: MouseClickView, mouseDownEvent: NSEvent) {
        field.makeMeFirstResponderIfNeeded()
    }

}
