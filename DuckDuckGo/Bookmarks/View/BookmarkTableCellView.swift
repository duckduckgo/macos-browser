//
//  BookmarkTableCellView.swift
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

import AppKit
import Foundation

@objc protocol BookmarkTableCellViewDelegate: AnyObject {

    func bookmarkTableCellViewRequestedMenu(_ sender: NSButton, cell: BookmarkTableCellView)
    func bookmarkTableCellViewToggledFavorite(cell: BookmarkTableCellView)
    func bookmarkTableCellView(_ cellView: BookmarkTableCellView, updatedBookmarkWithUUID uuid: String, newTitle: String, newUrl: String)

}

final class BookmarkTableCellView: NSTableCellView {

    private lazy var faviconImageView = NSImageView(image: .bookmark)

    private lazy var titleLabel = NSTextField(string: "Bookmark")
    private lazy var bookmarkURLLabel = NSTextField(string: "URL")
    private lazy var favoriteButton = NSButton(title: "", image: .favoriteFilledBorder, target: self, action: #selector(favoriteButtonClicked))
    private lazy var accessoryImageView = NSImageView(image: .forward)

    private var favoriteButtonBottomConstraint: NSLayoutConstraint!
    private var favoriteButtonTrailingConstraint: NSLayoutConstraint!

    private lazy var containerView = NSView()
    private lazy var shadowView = NSBox()

    private lazy var menuButton = NSButton(title: "", image: .settings, target: self, action: #selector(cellMenuButtonClicked))

    // Shadow view constraints:

    private var shadowViewTopConstraint: NSLayoutConstraint!
    private var shadowViewBottomConstraint: NSLayoutConstraint!

    // Container view constraints:

    private var titleLabelTopConstraint: NSLayoutConstraint!
    private var titleLabelBottomConstraint: NSLayoutConstraint!

    @objc func cellMenuButtonClicked(_ sender: NSButton) {
        delegate?.bookmarkTableCellViewRequestedMenu(sender, cell: self)
    }

    @objc func favoriteButtonClicked(_ sender: NSButton) {
        guard entity is Bookmark else {
            assertionFailure("\(#file): Tried to favorite non-Bookmark object")
            return
        }

        delegate?.bookmarkTableCellViewToggledFavorite(cell: self)
    }

    weak var delegate: BookmarkTableCellViewDelegate?

    var editing: Bool = false {
        didSet {
            if editing {
                enterEditingMode()
            } else {
                exitEditingMode()
            }
            updateColors()
        }
    }

    var isSelected = false {
        didSet {
            updateColors()
            updateTitleLabelValue()
        }
    }

    private var entity: BaseBookmarkEntity?
    private var trackingArea: NSTrackingArea?
    private var mouseInside: Bool = false {
        didSet {
            guard self.entity is Bookmark else {
                menuButton.isHidden = true
                return
            }

            accessoryImageView.isHidden = mouseInside || editing
            menuButton.isHidden = !mouseInside || editing

            if !mouseInside && !editing {
                resetAppearanceFromBookmark()
            }

            if !editing {
                updateTitleLabelValue()
            }
        }
    }

    init(identifier: NSUserInterfaceItemIdentifier, entity: BaseBookmarkEntity? = nil) {
        super.init(frame: NSRect(x: 0, y: 0, width: 462, height: 84))
        self.identifier = identifier

        setupUI()
        setupLayout()
        resetCellState()

        if let bookmark = entity as? Bookmark {
            update(from: bookmark)
        } else if let folder = entity as? BookmarkFolder {
            update(from: folder)
        } else if entity != nil {
            assertionFailure("Unsupported Bookmark Entity: \(entity!)")
        }
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    // swiftlint:disable:next function_body_length
    private func setupUI() {
        autoresizingMask = [.width, .height]

        addSubview(shadowView)
        addSubview(containerView)

        shadowView.boxType = .custom
        shadowView.borderColor = .clear
        shadowView.borderWidth = 1
        shadowView.cornerRadius = 4
        shadowView.fillColor = .tableCellEditingColor
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        shadowView.wantsLayer = true
        shadowView.layer?.backgroundColor = NSColor.tableCellEditingColor.cgColor
        shadowView.layer?.cornerRadius = 6

        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
        shadow.shadowBlurRadius = 2.0
        shadowView.shadow = shadow

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(faviconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(menuButton)
        containerView.addSubview(accessoryImageView)
        containerView.addSubview(bookmarkURLLabel)
        containerView.addSubview(favoriteButton)

        faviconImageView.contentTintColor = .suggestionIconColor
        faviconImageView.wantsLayer = true
        faviconImageView.layer?.cornerRadius = 2.0
        faviconImageView.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        faviconImageView.setContentHuggingPriority(.init(rawValue: 251), for: .vertical)
        faviconImageView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.focusRingType = .none
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.isSelectable = false
        titleLabel.drawsBackground = false
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.sendsActionOnEndEditing = true
        titleLabel.cell?.usesSingleLineMode = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        titleLabel.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        titleLabel.delegate = self

        bookmarkURLLabel.focusRingType = .none
        bookmarkURLLabel.isEditable = false
        bookmarkURLLabel.isSelectable = false
        bookmarkURLLabel.isBordered = false
        bookmarkURLLabel.drawsBackground = false
        bookmarkURLLabel.font = .systemFont(ofSize: 13)
        bookmarkURLLabel.textColor = .secondaryLabelColor
        bookmarkURLLabel.lineBreakMode = .byClipping
        bookmarkURLLabel.translatesAutoresizingMaskIntoConstraints = false
        bookmarkURLLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bookmarkURLLabel.setContentHuggingPriority(.required, for: .vertical)
        bookmarkURLLabel.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        bookmarkURLLabel.delegate = self

        accessoryImageView.translatesAutoresizingMaskIntoConstraints = false
        accessoryImageView.widthAnchor.constraint(equalToConstant: 22).isActive = true
        accessoryImageView.heightAnchor.constraint(equalToConstant: 32).isActive = true

        menuButton.contentTintColor = .buttonColor
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.isBordered = false
        menuButton.isHidden = true

        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        favoriteButton.isBordered = false
    }

    private func setupLayout() {

        trailingAnchor.constraint(equalTo: shadowView.trailingAnchor, constant: 3).isActive = true
        shadowView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3).isActive = true
        containerView.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor).isActive = true
        containerView.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor).isActive = true
        containerView.topAnchor.constraint(equalTo: shadowView.topAnchor).isActive = true
        containerView.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor).isActive = true

        bookmarkURLLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10).isActive = true
        favoriteButtonTrailingConstraint = trailingAnchor.constraint(equalTo: favoriteButton.trailingAnchor, constant: 3)
        favoriteButtonTrailingConstraint.isActive = true

        menuButton.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8).isActive = true
        faviconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6).isActive = true
        favoriteButton.topAnchor.constraint(equalTo: bookmarkURLLabel.bottomAnchor).isActive = true

        accessoryImageView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor).isActive = true
        titleLabel.leadingAnchor.constraint(equalTo: faviconImageView.trailingAnchor, constant: 8).isActive = true
        trailingAnchor.constraint(equalTo: accessoryImageView.trailingAnchor, constant: 3).isActive = true
        faviconImageView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor).isActive = true
        trailingAnchor.constraint(equalTo: menuButton.trailingAnchor, constant: 2).isActive = true
        bookmarkURLLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: bookmarkURLLabel.trailingAnchor, constant: 16).isActive = true
        menuButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor).isActive = true

        favoriteButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        favoriteButton.heightAnchor.constraint(equalToConstant: 24).isActive = true

        menuButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        menuButton.widthAnchor.constraint(equalToConstant: 28).isActive = true

        faviconImageView.heightAnchor.constraint(equalToConstant: 16).isActive = true
        faviconImageView.widthAnchor.constraint(equalToConstant: 16).isActive = true

        shadowViewTopConstraint = shadowView.topAnchor.constraint(equalTo: topAnchor, constant: 3)
        shadowViewTopConstraint.isActive = true

        shadowViewBottomConstraint = bottomAnchor.constraint(equalTo: shadowView.bottomAnchor, constant: 3)
        shadowViewBottomConstraint.isActive = true

        titleLabelBottomConstraint = bottomAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8)
        titleLabelBottomConstraint.priority = .init(rawValue: 250)
        titleLabelBottomConstraint.isActive = true

        favoriteButtonBottomConstraint = bottomAnchor.constraint(equalTo: favoriteButton.bottomAnchor, constant: 8)
        favoriteButtonBottomConstraint.priority = .init(rawValue: 750)
        favoriteButtonBottomConstraint.isActive = true

        titleLabelTopConstraint = titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 5)
        titleLabelTopConstraint.isActive = true
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            faviconImageView.contentTintColor = isSelected ? .white : .black
            updateTitleLabelValue()
        }
    }

    override var draggingImageComponents: [NSDraggingImageComponent] {
        let faviconComponent = NSDraggingImageComponent(key: .icon)
        faviconComponent.contents = faviconImageView.image
        faviconComponent.frame = faviconImageView.frame

        let labelComponent = NSDraggingImageComponent(key: .label)
        labelComponent.contents = titleLabel.imageRepresentation()
        labelComponent.frame = titleLabel.frame

        return [faviconComponent, labelComponent]
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        ensureTrackingArea()

        if !trackingAreas.contains(trackingArea!) {
            addTrackingArea(trackingArea!)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        mouseInside = true
    }

    override func mouseExited(with event: NSEvent) {
        mouseInside = false
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        resetCellState()
    }

    func update(from bookmark: Bookmark) {
        self.entity = bookmark

        faviconImageView.image = bookmark.favicon(.small) ?? .bookmarkDefaultFavicon

        if bookmark.isFavorite {
            accessoryImageView.isHidden = false
        }

        accessoryImageView.image = bookmark.isFavorite ? .favorite : nil
        favoriteButton.image = bookmark.isFavorite ? .favoriteFilledBorder : .favorite
        titleLabel.stringValue = bookmark.title
        primaryTitleLabelValue = bookmark.title
        tertiaryTitleLabelValue = bookmark.url
        bookmarkURLLabel.stringValue = bookmark.url
    }

    func update(from folder: BookmarkFolder) {
        self.entity = folder

        faviconImageView.image = .folder
        accessoryImageView.image = .chevronNext16
        primaryTitleLabelValue = folder.title
        tertiaryTitleLabelValue = nil
    }

    private func resetCellState() {
        self.entity = nil
        editing = false
        mouseInside = false
        bookmarkURLLabel.isHidden = true
        favoriteButton.isHidden = true
        titleLabelBottomConstraint.priority = .required
    }

    private func enterEditingMode() {
        titleLabel.isEditable = true
        bookmarkURLLabel.isEditable = true

        shadowViewTopConstraint.constant = 10
        shadowViewBottomConstraint.constant = 10
        titleLabelTopConstraint.constant = 12
        favoriteButtonTrailingConstraint.constant = 11
        favoriteButtonBottomConstraint.constant = 18
        shadowView.isHidden = false
        faviconImageView.isHidden = true

        bookmarkURLLabel.isHidden = false
        favoriteButton.isHidden = false
        titleLabelBottomConstraint.priority = .defaultLow

        hideTertiaryValueInTitleLabel()

        // Reluctantly use GCD as a workaround for a rare label layout issue, in which the text field shows no text upon becoming first responder.
        DispatchQueue.main.async {
            self.titleLabel.becomeFirstResponder()
        }
    }

    private func exitEditingMode() {
        window?.makeFirstResponder(nil)

        titleLabel.isEditable = false
        bookmarkURLLabel.isEditable = false

        titleLabelTopConstraint.constant = 5
        shadowViewTopConstraint.constant = 3
        shadowViewBottomConstraint.constant = 3
        favoriteButtonTrailingConstraint.constant = 3
        favoriteButtonBottomConstraint.constant = 8
        shadowView.isHidden = true
        faviconImageView.isHidden = false

        bookmarkURLLabel.isHidden = true
        favoriteButton.isHidden = true
        titleLabelBottomConstraint.priority = .required

        if let editedBookmark = self.entity as? Bookmark {
            delegate?.bookmarkTableCellView(self,
                                            updatedBookmarkWithUUID: editedBookmark.id,
                                            newTitle: titleLabel.stringValue,
                                            newUrl: bookmarkURLLabel.stringValue)
        }
    }

    private func updateColors() {
        titleLabel.textColor = isSelected && !editing ? .white : .controlTextColor
        menuButton.contentTintColor = isSelected ? .white : .buttonColor
        faviconImageView.contentTintColor = isSelected ? .white : .suggestionIconColor
        accessoryImageView.contentTintColor = isSelected ? .white : .suggestionIconColor
    }

    private func ensureTrackingArea() {
        if trackingArea == nil {
            trackingArea = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .activeAlways, .mouseEnteredAndExited], owner: self, userInfo: nil)
        }
    }

    /// Provides the primary value displayed in the title label. This value will be rendered with a black text color.
    private var primaryTitleLabelValue = "" {
        didSet {
            updateTitleLabelValue()
        }
    }

    /// Provides the tertiary value displayed in the title label when the cell is selected. This value will be rendered with a lighter text color to the main text.
    private var tertiaryTitleLabelValue: String? {
        didSet {
            updateTitleLabelValue()
        }
    }

    private func resetAppearanceFromBookmark() {
        if let bookmark = self.entity as? Bookmark {
            update(from: bookmark)
        } else if let folder = self.entity as? BookmarkFolder {
            update(from: folder)
        } else {
            assertionFailure("\(#file): Failed to update cell from bookmark entity")
        }
    }

    private func updateTitleLabelValue() {
        guard !editing else {
            return
        }

        if let tertiaryValue = tertiaryTitleLabelValue, mouseInside, !editing {
            showTertiaryValueInTitleLabel(tertiaryValue)
        } else {
            hideTertiaryValueInTitleLabel()
        }
    }

    private func showTertiaryValueInTitleLabel(_ tertiaryValue: String) {
        titleLabel.stringValue = ""
        titleLabel.attributedStringValue = buildTitleAttributedString(tertiaryValue: tertiaryValue)
    }

    private func hideTertiaryValueInTitleLabel() {
        titleLabel.attributedStringValue = NSAttributedString()
        titleLabel.stringValue = primaryTitleLabelValue
    }

    private func buildTitleAttributedString(tertiaryValue: String) -> NSAttributedString {
        let color = isSelected ? NSColor.white : NSColor.labelColor

        let titleAttributes = [NSAttributedString.Key.foregroundColor: color]
        let titleString = NSMutableAttributedString(string: primaryTitleLabelValue, attributes: titleAttributes)

        let urlColor = isSelected ? NSColor.white.withAlphaComponent(0.6) : NSColor.tertiaryLabelColor

        let urlAttributes = [NSAttributedString.Key.foregroundColor: urlColor]
        let urlString = NSAttributedString(string: " – \(tertiaryValue)", attributes: urlAttributes)

        titleString.append(urlString)

        return titleString
    }

}

extension BookmarkTableCellView: NSTextFieldDelegate {

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(cancelOperation) where self.editing:
            self.resetAppearanceFromBookmark()
            self.editing = false
            return true

        case #selector(insertNewline) where self.editing:
            self.editing = false
            return true

        default: break
        }
        return false
    }

}

#if DEBUG
@available(macOS 14.0, *)
#Preview {
    BookmarkTableCellView.PreviewView(cell: BookmarkTableCellView(identifier: .init("id"), entity: Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: false)))
}

extension BookmarkTableCellView {
    final class PreviewView: NSView, BookmarkTableCellViewDelegate {

        let cell: BookmarkTableCellView

        init(cell: BookmarkTableCellView) {
            self.cell = cell
            super.init(frame: .zero)
            wantsLayer = true
            layer!.backgroundColor = NSColor.white.cgColor

            translatesAutoresizingMaskIntoConstraints = true
            widthAnchor.constraint(equalToConstant: 512).isActive = true

            cell.frame = bounds
            self.addSubview(cell)

            cell.delegate = self
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func bookmarkTableCellViewRequestedMenu(_ sender: NSButton, cell: BookmarkTableCellView) {
            cell.editing.toggle()
        }

        func bookmarkTableCellViewToggledFavorite(cell: BookmarkTableCellView) {
            (cell.entity as? Bookmark)?.isFavorite.toggle()
            cell.editing = false
        }

        func bookmarkTableCellView(_ cellView: BookmarkTableCellView, updatedBookmarkWithUUID uuid: String, newTitle: String, newUrl: String) {
            if cell.editing {
                cell.editing = false
            }
        }
    }
}
#endif
