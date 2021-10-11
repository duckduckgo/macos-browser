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
        }
    }

    var tabViewCollectionModel: TabCollectionViewModel? {
        didSet {
            field.tabCollectionViewModel = tabViewCollectionModel
        }
    }

    private let suggestionContainerViewModel = SuggestionContainerViewModel(suggestionContainer: SuggestionContainer())

    @IBOutlet weak var field: AddressBarTextField!
    @IBOutlet weak var icon: NSImageView!

    var fieldCancellable: AnyCancellable?

    override func awakeFromNib() {
        super.awakeFromNib()
        print(#function)
        field.suggestionContainerViewModel = suggestionContainerViewModel
        subscribeToField()
        updateTextFieldIcon()
    }

    private func subscribeToField() {
        fieldCancellable = field.$value.receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self = self else { return }
            self.updateMode()
        }
    }

    private func updateMode() {
        print(#function, field.value)
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

}
