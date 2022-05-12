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
