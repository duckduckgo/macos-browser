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

import Foundation

@objc protocol BookmarkTableCellViewDelegate: AnyObject {

    func bookmarkTableCellViewRequestedMenu(_ sender: NSButton, cell: BookmarkTableCellView)
    func bookmarkTableCellViewToggledFavorite(cell: BookmarkTableCellView)
    func bookmarkTableCellView(_ cellView: BookmarkTableCellView, updatedBookmarkWithUUID uuid: UUID, newTitle: String, newUrl: String)

}

final class BookmarkTableCellView: NSTableCellView, NibLoadable {

    static private var defaultBookmarkFavicon = NSImage(named: "Web")
    static private var folderAccessoryViewImage = NSImage(named: "Chevron-Next-16")
    static private var favoriteAccessoryViewImage = NSImage(named: "Favorite")
    static private var favoriteFilledAccessoryViewImage = NSImage(named: "FavoriteFilledBorder")
    static private var ellipsisAccessoryViewImage = NSImage(named: "Settings")

    @IBOutlet var faviconImageView: NSImageView! {
        didSet {
            faviconImageView.wantsLayer = true
            faviconImageView.layer?.cornerRadius = 2.0
        }
    }

    @IBOutlet var titleLabel: NSTextField!
    @IBOutlet var bookmarkURLLabel: NSTextField!
    @IBOutlet var favoriteButton: NSButton!
    @IBOutlet var accessoryImageView: NSImageView!
    @IBOutlet var shadowView: NSView! {
        didSet {
            shadowView.isHidden = true
            shadowView.wantsLayer = true
            shadowView.layer?.backgroundColor = NSColor.tableCellEditingColor.cgColor
            shadowView.layer?.cornerRadius = 6

            let shadow = NSShadow()
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
            shadow.shadowBlurRadius = 2.0

            shadowView.shadow = shadow
        }
    }

    @IBOutlet var menuButton: NSButton! {
        didSet {
            menuButton.isHidden = true
        }
    }

    // Shadow view constraints:

    @IBOutlet var shadowViewTopConstraint: NSLayoutConstraint!
    @IBOutlet var shadowViewBottomConstraint: NSLayoutConstraint!

    // Container view constraints:

    @IBOutlet var titleLabelTopConstraint: NSLayoutConstraint!
    @IBOutlet var titleLabelBottomConstraint: NSLayoutConstraint!

    @IBAction func cellMenuButtonClicked(_ sender: NSButton) {
        delegate?.bookmarkTableCellViewRequestedMenu(sender, cell: self)
    }

    @IBAction func favoriteButtonClicked(_ sender: NSButton) {
        guard entity is Bookmark else {
            assertionFailure("\(#file): Tried to favorite non-Bookmark object")
            return
        }

        delegate?.bookmarkTableCellViewToggledFavorite(cell: self)
    }

    @IBOutlet weak var delegate: BookmarkTableCellViewDelegate?

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

    override func awakeFromNib() {
        super.awakeFromNib()
        resetCellState()
    }

    func update(from bookmark: Bookmark) {
        self.entity = bookmark

        faviconImageView.image = bookmark.favicon(.small) ?? NSImage(named: "BookmarkDefaultFavicon")
        
        if bookmark.isFavorite {
            accessoryImageView.isHidden = false
        }
        
        accessoryImageView.image = bookmark.isFavorite ? Self.favoriteAccessoryViewImage : nil
        favoriteButton.image = bookmark.isFavorite ? Self.favoriteFilledAccessoryViewImage : Self.favoriteAccessoryViewImage
        primaryTitleLabelValue = bookmark.title
        tertiaryTitleLabelValue = bookmark.url.absoluteString
        bookmarkURLLabel.stringValue = bookmark.url.absoluteString
    }

    func update(from folder: BookmarkFolder) {
        self.entity = folder

        faviconImageView.image = NSImage(named: "Folder")
        accessoryImageView.image = Self.folderAccessoryViewImage
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

        titleLabelTopConstraint.constant = 6
        shadowViewTopConstraint.constant = 3
        shadowViewBottomConstraint.constant = 3
        shadowView.isHidden = true
        faviconImageView.isHidden = false

        bookmarkURLLabel.isHidden = true
        favoriteButton.isHidden = true
        titleLabelBottomConstraint.priority = .required

        if let editedBookmark = self.entity as? Bookmark,
           titleLabel.stringValue != editedBookmark.title || bookmarkURLLabel.stringValue != editedBookmark.url.absoluteString {
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
