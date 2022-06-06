//
//  BookmarksBarButton.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

final class BookmarksBarButton: NSButton {
    
    let backgroundLayer = CALayer()
    
    private let faviconImageView = NSImageView(frame: CGRect(x: 3, y: 3, width: 16, height: 16))
    
    private var isMouseOver = false {
        didSet {
            updateLayer()
        }
    }

    convenience init(bookmark: Bookmark) {
        self.init(frame: .zero)
        update(from: bookmark)
    }
    
    convenience init(folder: BookmarkFolder) {
        self.init(frame: .zero)
        update(from: folder)
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        self.cell = BookmarksBarButtonCell()
        
        addSubview(faviconImageView)
        faviconImageView.layer?.cornerRadius = 3
        faviconImageView.layer?.masksToBounds = true

        configureLayers()
        addTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sizeToFit() {
        super.sizeToFit()
        
        let updatedFrame = self.frame.insetBy(dx: -3, dy: -3)
        self.frame = updatedFrame
    }
    
    // MARK: - Interface Updates
    
    private func update(from bookmark: Bookmark) {
        let favicon = FaviconManager.shared.getCachedFavicon(for: bookmark.url, sizeCategory: .small)?.image ?? NSImage(named: "Bookmark")
        faviconImageView.image = favicon
    }
    
    private func update(from folder: BookmarkFolder) {
        faviconImageView.image = NSImage(named: "Folder-16")
    }

    private func configureLayers() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.backgroundLayer.masksToBounds = true
        self.layer?.addSublayer(backgroundLayer)
    }

    // MARK: - Tracking
    
    private func addTrackingArea() {
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isMouseOver = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isMouseOver = false
    }

    override func updateLayer() {
        backgroundLayer.cornerRadius = 4.0
        backgroundLayer.frame = layer!.bounds

        guard isEnabled else {
            backgroundLayer.backgroundColor = NSColor.clear.cgColor
            return
        }

        NSAppearance.withAppAppearance {
            if isMouseOver {
                backgroundLayer.backgroundColor = NSColor(named: "ButtonMouseOverColor")?.cgColor ?? NSColor.clear.cgColor
            } else {
                backgroundLayer.backgroundColor = NSColor.clear.cgColor
            }
        }
    }
    
}
