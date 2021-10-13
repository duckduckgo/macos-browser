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
import WebKit

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
    @IBOutlet weak var container: NSView!
    @IBOutlet weak var field: AddressBarTextField!
    @IBOutlet weak var shadowView: ShadowView!
    @IBOutlet weak var icon: NSImageView!
    @IBOutlet weak var backgroundHeight: NSLayoutConstraint!
    @IBOutlet weak var dax: WKWebView!
    @IBOutlet weak var clearButton: NSView!

    private var fieldCancellable: AnyCancellable?
    private var suggestionsCancellable: AnyCancellable?
    private var animationTimer: Timer?

    override func awakeFromNib() {
        super.awakeFromNib()

        initLogo()
        initShadows()
        initFieldBackground()
        wireUpAddressBarFieldToModel()
        subscribeToField()
        updateTextFieldIcon()
    }

    override func updateLayer() {
        super.updateLayer()
        initFieldBackground()
    }

    @objc func textFieldFirstReponderNotification(_ notification: Notification) {
        if mode != .idle {
            self.mode = .idle
        }
        updateSearchView()
    }

    @IBAction func clearText(_ sender: Any) {
        field.clearValue()
    }

    private func wireUpAddressBarFieldToModel() {
        field.suggestionContainerViewModel = suggestionContainerViewModel
    }

    private func initFieldBackground() {
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 8
        backgroundView.layer?.backgroundColor = NSColor.addressBarBackgroundColor.cgColor
        backgroundView.layer?.borderColor = NSColor.addressBarBorderColor.cgColor
        backgroundView.layer?.borderWidth = 1
        (container as? MouseClickView)?.delegate = self
    }

    private func initShadows() {
        wantsLayer = true
        layer?.masksToBounds = false
        shadowView.shadowColor = .suggestionsShadowColor
        shadowView.shadowRadius = 8.0
    }

    private func initLogo() {
        guard let daxLogo = Bundle.main.url(forResource: "Dax", withExtension: "svg") else { fatalError() }
        dax.loadFileURL(daxLogo, allowingReadAccessTo: daxLogo)
        dax.setValue(false, forKey: "drawsBackground")
        dax.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(onGesture(_:))))
        startAnimation()
    }

    @objc func onGesture(_ gesture: NSGestureRecognizer) {
        runAnimation()
    }

    private func startAnimation() {
        animationTimer?.invalidate()
        let delay: TimeInterval = Double.random(in: 30 ..< 120)
        animationTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false, block: { [weak self] _ in
            self?.runAnimation()
        })
    }

    private func runAnimation() {
        animationTimer?.invalidate()
        let anim = ["Dax-Wink", "Dax-Bow-Tie", "Dax-EyeBrows", "Dax-Eyes"].randomElement()
        guard let daxAnim = Bundle.main.url(forResource: anim, withExtension: "svg") else { fatalError() }
        dax.loadFileURL(daxAnim, allowingReadAccessTo: daxAnim)
        startAnimation()
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
        backgroundHeight.constant = container.frame.height
        shadowView.isHidden = true
        clearButton.isHidden = true
    }

    private func showSearchActive() {
        backgroundHeight.constant = container.frame.height
        shadowView.isHidden = false
        shadowView.shadowSides = .all
        clearButton.isHidden = field.value.isEmpty
    }

    private func showSearchHasResults() {
        clearButton.isHidden = false
        backgroundHeight.constant = container.frame.height + 10
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

}

extension HomepageHeaderView: MouseClickViewDelegate {

    func mouseClickView(_ mouseClickView: MouseClickView, mouseDownEvent: NSEvent) {
        field.makeMeFirstResponderIfNeeded()
    }

}

final class DaxWebView: WKWebView {

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        super.init(frame: frame, configuration: config)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        menu.removeAllItems()
    }

}
