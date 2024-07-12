//
//  FirePopoverCollectionViewHeader.swift
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

final class FirePopoverCollectionViewHeader: NSView {

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: FirePopoverCollectionViewHeader.className())
    fileprivate static let size = NSSize(width: 200, height: 28)

    private(set) lazy var title = NSTextField(string: UserText.fireproofSites)

    override init(frame: NSRect = NSRect(origin: .zero, size: FirePopoverCollectionViewHeader.size)) {
        super.init(frame: frame)
        identifier = Self.identifier
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("FirePopoverCollectionViewHeader: Bad initializer")
    }

    private func setupUI() {
        addSubview(title)

        title.translatesAutoresizingMaskIntoConstraints = false
        title.setContentHuggingPriority(.defaultHigh, for: .vertical)
        title.setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 251), for: .horizontal)
        title.isEditable = false
        title.isSelectable = false
        title.isBordered = false
        title.drawsBackground = false
        title.alignment = .left
        title.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .light)
        title.textColor = .secondaryLabelColor

        setupLayout()
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 4),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            trailingAnchor.constraint(equalTo: title.trailingAnchor, constant: 8),
        ])
    }

    override func mouseDown(with event: NSEvent) {}

}

@available(macOS 14.0, *)
#Preview(traits: FirePopoverCollectionViewHeader.size.scaled(by: 1.5).fixedLayout) { {
    let vc = NSViewController()
    vc.view = NSView(frame: NSRect(origin: .zero, size: FirePopoverCollectionViewHeader.size.scaled(by: 1.5)))
    let header = FirePopoverCollectionViewHeader()
    header.translatesAutoresizingMaskIntoConstraints = true
    header.frame = NSRect(origin: NSPoint(x: (vc.view.frame.size.width - FirePopoverCollectionViewHeader.size.width) / 2, y: (vc.view.frame.size.height - FirePopoverCollectionViewHeader.size.height) / 2), size: FirePopoverCollectionViewHeader.size)
    header.wantsLayer = true
    header.layer!.backgroundColor = NSColor.fireBackground.cgColor
    vc.view.addSubview(header)
    return vc._preview_hidingWindowControlsOnAppear()
}() }
