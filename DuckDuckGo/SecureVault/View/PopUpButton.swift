//
//  PopUpButton.swift
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

import AppKit
import Foundation

private struct NSMenuItemColor {
    let foregroundColor: NSColor?
    let backgroundColor: NSColor
}

final class PopUpButton: NSPopUpButton {

    var backgroundColorCell: NSPopUpButtonBackgroundColorCell? {
        return self.cell as? NSPopUpButtonBackgroundColorCell
    }

    init() {
        super.init(frame: .zero, pullsDown: true)
        self.cell = NSPopUpButtonBackgroundColorCell()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.cell = NSPopUpButtonBackgroundColorCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func add(_ item: NSMenuItem, withForegroundColor foregroundColor: NSColor?, backgroundColor: NSColor) {
        self.menu?.addItem(item)

        let itemColor = NSMenuItemColor(foregroundColor: foregroundColor, backgroundColor: backgroundColor)
        backgroundColorCell?.colors[item.title] = itemColor
    }

}

final class NSPopUpButtonBackgroundColorCell: NSPopUpButtonCell {

    private static let chevronsImage = NSImage.popUpButtonChevrons

    fileprivate var colors: [String: NSMenuItemColor] = [:]

    private func foregroundColor(for title: String) -> NSColor {
        if let color = colors[title]?.foregroundColor {
            return color
        } else {
            return NSApplication.shared.effectiveAppearance.name == .aqua ? .black : .white
        }
    }

    override func drawTitle(withFrame cellFrame: NSRect, in controlView: NSView) {
        let font = self.font ?? NSFont.systemFont(ofSize: 15)

        let string = NSAttributedString(string: title, attributes: [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: foregroundColor(for: title)
        ])

        var titleRect = titleRect(forBounds: cellFrame)
        titleRect.origin.y += 2
        string.draw(in: titleRect)
    }

    override func drawImage(withFrame cellFrame: NSRect, in controlView: NSView) {
        let color = foregroundColor(for: title)
        guard let tintedImage = image?.tinted(with: color) else {
            return
        }

        var imageRect = imageRect(forBounds: cellFrame)
        imageRect.origin.y += 1

        tintedImage.draw(in: imageRect)
    }

    override func drawBezel(withFrame frame: NSRect, in controlView: NSView) {
        guard let color = colors[title] else {
            return
        }

        let horizontalOffset: CGFloat = 3
        var modifiedFrame = frame
        modifiedFrame.origin.x += horizontalOffset
        modifiedFrame.size.width -= horizontalOffset
        modifiedFrame.size.height -= 1

        color.backgroundColor.setFill()

        let backgroundPath = NSBezierPath(roundedRect: modifiedFrame, xRadius: 5, yRadius: 5)
        backgroundPath.fill()

        let foregroundColor = foregroundColor(for: title)

        let tintedChevrons = Self.chevronsImage.tinted(with: foregroundColor)
        let chevronFrame = NSRect(x: frame.size.width - Self.chevronsImage.size.width - 4,
                                  y: frame.size.height / 2 - Self.chevronsImage.size.height / 2,
                                  width: Self.chevronsImage.size.width,
                                  height: Self.chevronsImage.size.height)

        tintedChevrons.draw(in: chevronFrame)
    }

}
