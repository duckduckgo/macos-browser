//
//  PermissionButton.swift
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

final class PermissionButton: AddressBarButton {

    private var defaultImage: NSImage?
    private var defaultTint: NSColor?
    @IBInspectable var activeImage: NSImage?
    @IBInspectable var activeTintColor: NSColor?
    @IBInspectable var inactiveImage: NSImage?
    @IBInspectable var inactiveTintColor: NSColor?
    @IBInspectable var disabledImage: NSImage?
    @IBInspectable var disabledTintColor: NSColor?
    @IBInspectable var mutedImage: NSImage?
    @IBInspectable var mutedTintColor: NSColor?

    var buttonState: PermissionState? {
        didSet {
            var isHidden = false
            switch buttonState {
            case .none, .reloading:
                isHidden = true
            case .active:
                self.image = activeImage ?? defaultImage
                self.normalTintColor = activeTintColor
                self.setAccessibilityValue("active")
            case .paused:
                self.image = mutedImage ?? defaultImage
                self.normalTintColor = mutedTintColor
                self.setAccessibilityValue("paused")
            case .disabled, .denied, .revoking:
                self.image = disabledImage ?? defaultImage
                self.normalTintColor = disabledTintColor
                self.setAccessibilityValue("disabled-denied-revoking")
            case .requested:
                self.image = defaultImage
                self.normalTintColor = defaultTint
                self.setAccessibilityValue("requested")
            case .inactive:
                self.image = inactiveImage ?? defaultImage
                self.normalTintColor = inactiveTintColor ?? defaultTint
                self.setAccessibilityValue("inactive")
            }
            self.isHidden = isHidden
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        wantsLayer = true
        defaultImage = self.image
        defaultTint = self.contentTintColor
        buttonState = .inactive
    }

}
