//
//  AddressBarButton.swift
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

internal class AddressBarButton: MouseOverButton {

    override func awakeFromNib() {
        super.awakeFromNib()

        wantsLayer = true
    }

    enum Position {
        case left
        case center
        case right
        case free
    }

    var position: Position = .center {
        didSet {
            guard let backgroundLayer = super.backgroundLayer(createIfNeeded: true) else {
                assertionFailure("no background layer")
                return
            }
            switch position {
            case .left:
                backgroundLayer.maskedCorners = [.layerMinXMaxYCorner, .layerMinXMinYCorner]
            case .center:
                backgroundLayer.maskedCorners = []
            case .right:
                backgroundLayer.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner]
            case .free:
                backgroundLayer.maskedCorners = [.layerMaxXMaxYCorner,
                                                 .layerMaxXMinYCorner,
                                                 .layerMinXMaxYCorner,
                                                 .layerMinXMinYCorner]
            }
            backgroundLayer.masksToBounds = true
        }
    }

}
