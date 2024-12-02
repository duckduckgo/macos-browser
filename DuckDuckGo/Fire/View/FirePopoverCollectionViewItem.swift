//
//  FirePopoverCollectionViewItem.swift
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

protocol FirePopoverCollectionViewItemDelegate: AnyObject {

    func firePopoverCollectionViewItemDidToggle(_ firePopoverCollectionViewItem: FirePopoverCollectionViewItem)

}

final class FirePopoverCollectionViewItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: FirePopoverCollectionViewItem.className())
    fileprivate static let size = NSSize(width: 265, height: 24)

    weak var delegate: FirePopoverCollectionViewItemDelegate?

    private lazy var domainTextField = NSTextField(string: "exampledomain.com")
    private lazy var checkButton = NSButton(title: "", target: self, action: #selector(checkButtonAction))
    private lazy var faviconImageView = NSImageView(image: .web)
    private lazy var stackView = NSStackView()

    override init(nibName: String? = nil, bundle: Bundle? = nil) {
        super.init(nibName: nil, bundle: nil)
        identifier = Self.identifier
    }

    required init?(coder: NSCoder) {
        fatalError("FirePopoverCollectionViewItem: Bad initializer")
    }

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: Self.size))

        stackView.addArrangedSubview(checkButton)
        stackView.addArrangedSubview(faviconImageView)
        stackView.addArrangedSubview(domainTextField)

        stackView.alignment = .centerY
        stackView.detachesHiddenViews = true
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        domainTextField.translatesAutoresizingMaskIntoConstraints = false
        domainTextField.setContentHuggingPriority(.defaultHigh, for: .vertical)
        domainTextField.setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 251), for: .horizontal)
        domainTextField.isEditable = false
        domainTextField.isSelectable = false
        domainTextField.isBordered = false
        domainTextField.drawsBackground = false
        domainTextField.font = .systemFont(ofSize: 13)
        domainTextField.lineBreakMode = .byClipping
        domainTextField.textColor = .labelColor

        faviconImageView.translatesAutoresizingMaskIntoConstraints = false
        faviconImageView.setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 251), for: .horizontal)
        faviconImageView.setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 251), for: .vertical)
        faviconImageView.alignment = .left
        faviconImageView.imageScaling = .scaleProportionallyDown
        faviconImageView.applyFaviconStyle()

        checkButton.translatesAutoresizingMaskIntoConstraints = false
        checkButton.setContentHuggingPriority(.defaultHigh, for: .vertical)
        checkButton.setButtonType(.switch)
        checkButton.bezelStyle = .regularSquare
        checkButton.font = .systemFont(ofSize: 13)

        view.addSubview(stackView)

        setupLayout(stackView: stackView)
    }

    private func setupLayout(stackView: NSStackView) {
        NSLayoutConstraint.activate([
            view.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),

            faviconImageView.widthAnchor.constraint(equalToConstant: 16),
            faviconImageView.heightAnchor.constraint(equalToConstant: 16),

            checkButton.heightAnchor.constraint(equalToConstant: 14),
            checkButton.widthAnchor.constraint(equalToConstant: 14),
        ])
    }

    func setItem(_ item: FirePopoverViewModel.Item, isFireproofed: Bool) {
        domainTextField.stringValue = item.domain
        faviconImageView.image = item.favicon ?? .web
        checkButton.isHidden = isFireproofed
    }

    @objc func checkButtonAction(_ sender: Any) {
        delegate?.firePopoverCollectionViewItemDidToggle(self)
    }

    override func mouseDown(with event: NSEvent) {
        delegate?.firePopoverCollectionViewItemDidToggle(self)
    }

    override var isSelected: Bool {
        didSet {
            checkButton.state = isSelected ? .on : .off
        }
    }

}

@available(macOS 14.0, *)
#Preview(traits: FirePopoverCollectionViewItem.size.scaled(by: 1.5).fixedLayout) { {
    let vc = NSViewController()
    vc.view = NSView(frame: NSRect(origin: .zero, size: FirePopoverCollectionViewItem.size.scaled(by: 1.5)))
    let cell = FirePopoverCollectionViewItem()
    cell.view.translatesAutoresizingMaskIntoConstraints = true
    cell.view.frame = NSRect(origin: NSPoint(x: (vc.view.frame.size.width - FirePopoverCollectionViewItem.size.width) / 2, y: (vc.view.frame.size.height - FirePopoverCollectionViewItem.size.height) / 2), size: FirePopoverCollectionViewItem.size)
    cell.view.wantsLayer = true
    cell.view.layer!.backgroundColor = NSColor.fireBackground.cgColor
    vc.view.addSubview(cell.view)
    vc.addChild(cell)
    return vc._preview_hidingWindowControlsOnAppear()
}() }
