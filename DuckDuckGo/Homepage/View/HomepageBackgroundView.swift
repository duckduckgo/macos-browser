//
//  HomepageBackgroundView.swift
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

final class HomepageBackgroundView: NSView {

    @IBOutlet weak var collectionView: NSCollectionView!
    weak var defaultBrowserPromptView: DefaultBrowserPromptView?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    @IBInspectable var backgroundColor: NSColor? = NSColor.clear {
        didSet {
            layer?.backgroundColor = backgroundColor?.cgColor
        }
    }

    override func layout() {
        var frame = bounds
        if let defaultBrowserPromptView = defaultBrowserPromptView,
           !defaultBrowserPromptView.isHidden {
            frame.size.height -= defaultBrowserPromptView.frame.height
        }
        collectionView.enclosingScrollView?.frame = frame
    }

    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = backgroundColor?.cgColor
    }

}
