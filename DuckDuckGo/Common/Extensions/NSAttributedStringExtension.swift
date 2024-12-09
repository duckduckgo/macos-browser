//
//  NSAttributedStringExtension.swift
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
import Utilities

typealias NSAttributedStringBuilder = ArrayBuilder<NSAttributedString>
extension NSAttributedString {

    /// These values come from Figma.  Click on the text in Figma and choose Code > iOS to see the values.
    static func make(_ string: String, lineHeight: CGFloat, kern: CGFloat, alignment: NSTextAlignment = .center) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = lineHeight
        paragraphStyle.alignment = alignment

        return NSMutableAttributedString(string: string, attributes: [
            NSAttributedString.Key.kern: kern, NSAttributedString.Key.paragraphStyle: paragraphStyle
        ])
    }

    convenience init(image: NSImage, rect: CGRect) {
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = rect
        self.init(attachment: attachment)
    }

    convenience init(@NSAttributedStringBuilder components: () -> [NSAttributedString]) {
        let components = components()
        guard !components.isEmpty else {
            self.init()
            return
        }
        guard components.count > 1 else {
            self.init(attributedString: components[0])
            return
        }
        let result = NSMutableAttributedString(attributedString: components[0])
        for component in components[1...] {
            result.append(component)
        }

        self.init(attributedString: result)
    }

}

extension NSMutableAttributedString {

    @discardableResult
    public func addLink(_ linkURL: String, toText text: String) -> Bool {
        let foundRange = self.mutableString.range(of: text)

        if foundRange.location != NSNotFound {
            self.addAttribute(.link, value: linkURL, range: foundRange)
            return true
        }

        return false
    }

}

extension NSMutableAttributedString {

    /// Applies bold and custom font sizes to specific parts of the string.
    /// - Parameters:
    ///   - string: The full string content to be processed.
    ///   - defaultFontSize: The default font size for regular text.
    ///   - boldFontSize: The font size for bold text (enclosed in `*` characters).
    ///   - customPart: The substring to which the custom font size should be applied.
    ///   - customFontSize: The custom font size for the specified substring.
    static func attributedString(from string: String,
                                 defaultFontSize: CGFloat,
                                 boldFontSize: CGFloat,
                                 customPart: String,
                                 customFontSize: CGFloat) -> NSMutableAttributedString {

        let attributedString = NSMutableAttributedString()

        var isBold = false
        var currentText = ""

        let boldFont = NSFont.systemFont(ofSize: boldFontSize, weight: .bold)
        let regularFont = NSFont.systemFont(ofSize: defaultFontSize)

        // Iterate through the string, applying bold where needed
        for character in string {
            if character == "*" {
                if !currentText.isEmpty {
                    let attributes: [NSAttributedString.Key: Any] = isBold ?
                        [.font: boldFont] :
                        [.font: regularFont]
                    attributedString.append(NSAttributedString(string: currentText, attributes: attributes))
                    currentText = ""
                }
                isBold.toggle()
            } else {
                currentText.append(character)
            }
        }

        // Add any remaining text
        if !currentText.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = isBold ?
                [.font: boldFont] :
                [.font: regularFont]
            attributedString.append(NSAttributedString(string: currentText, attributes: attributes))
        }

        // Apply the custom font to the specific part of the string
        let customFont = NSFont.systemFont(ofSize: customFontSize)
        let customFontAttribute: [NSAttributedString.Key: Any] = [.font: customFont]

        let fullText = attributedString.string as NSString
        let customRange = fullText.range(of: customPart)

        if customRange.location != NSNotFound {
            attributedString.addAttributes(customFontAttribute, range: customRange)
        }

        return attributedString
    }
}
