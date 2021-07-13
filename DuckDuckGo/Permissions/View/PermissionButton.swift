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
    @IBInspectable var disabledImage: NSImage?
    @IBInspectable var disabledTintColor: NSColor?
    @IBInspectable var mutedImage: NSImage?
    @IBInspectable var mutedTintColor: NSColor?

    enum ButtonState {
        case inactive
        case requested
        case active
        case muted
        case disabled

        init(isRequested: Bool, isDenied: Bool, permissionState: PermissionState?) {
            if isRequested {
                self = .requested
            } else if isDenied {
                self = .disabled
            } else if case .some(.active) = permissionState {
                self = .active
            } else if case .some(.paused) = permissionState {
                self = .muted
            } else {
                self = .inactive
            }
        }
    }

    var buttonState: ButtonState = .inactive {
        didSet {
            var isHidden = false
            switch buttonState {
            case .inactive:
                isHidden = true
            case .active:
                self.image = activeImage ?? defaultImage
                self.contentTintColor = activeTintColor
            case .muted:
                self.image = mutedImage ?? defaultImage
                self.contentTintColor = mutedTintColor
            case .disabled:
                self.image = disabledImage ?? defaultImage
                self.contentTintColor = disabledTintColor
            case .requested:
                self.image = defaultImage
                self.contentTintColor = defaultTint
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
