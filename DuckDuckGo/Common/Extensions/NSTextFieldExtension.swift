//
//  NSTextFieldExtension.swift
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
import Common
import os.log

extension NSTextField {

    var isFirstResponder: Bool {
        window?.firstResponder == currentEditor()
    }

    static func label(titled title: String) -> NSTextField {
        let label = NSTextField(string: title)

        label.isEditable = false
        label.isBordered = false
        label.isSelectable = false
        label.isBezeled = false
        label.backgroundColor = .clear

        return label
    }

    func setEditable(_ editable: Bool) {
        self.isEditable = editable
        self.isBordered = editable
        self.isSelectable = editable
        self.isBezeled = editable
    }

    static func optionalLabel(titled title: String?) -> NSTextField? {
        guard let title = title else {
            return nil
        }

        return label(titled: title)
    }

    func gradient(width: CGFloat, trailingPadding: CGFloat) {
        guard let layer = layer else {
            Logger.general.error("NSTextField: Making of gradient failed - Text field has no layer.")
            return
        }

        if layer.mask == nil {
            let maskGradientLayer = CAGradientLayer()
            layer.mask = maskGradientLayer
            maskGradientLayer.colors = [NSColor.white.cgColor, NSColor.clear.cgColor]
        }

        guard let mask = layer.mask as? CAGradientLayer else {
            Logger.general.error("NSTextField: Making of gradient failed - Mask has no gradient layer.")
            return
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0)

        mask.frame = layer.bounds

        let startPointX = (mask.bounds.width - (trailingPadding + width)) / mask.bounds.width
        let endPointX = (mask.bounds.width - trailingPadding) / mask.bounds.width

        mask.startPoint = CGPoint(x: startPointX, y: 0.5)
        mask.endPoint = CGPoint(x: endPointX, y: 0.5)

        CATransaction.commit()
    }

}
