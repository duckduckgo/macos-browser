//
//  SuggestionTableRowView.swift
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

final class SuggestionTableRowView: NSTableRowView {

    static let identifier = "SuggestionTableRowView"

    override func awakeFromNib() {
        super.awakeFromNib()

        setupView()
        updateBackgroundColor()
    }

    override var isEmphasized: Bool {
        get { return true }
        set {}
    }

    override var isSelected: Bool {
        didSet {
            updateCellView()
            updateBackgroundColor()
        }
    }

    var isBurner: Bool = false

    private func setupView() {
        selectionHighlightStyle = .none
        wantsLayer = true
        layer?.cornerRadius = 3
    }

    private func updateBackgroundColor() {
        let accentColor: NSColor = isBurner ? .burnerAccent : .controlAccentColor
        backgroundColor = isSelected ? accentColor : .clear
    }

    private func updateCellView() {
        for subview in subviews {
            if let cellView = subview as? SuggestionTableCellView {
                cellView.isSelected = isSelected
                isBurner = cellView.isBurner
            }
        }
    }

    override func layout() {
        super.layout()

        updateCellView()
        updateBackgroundColor()
    }

}
