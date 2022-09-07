//
//  PrivateYoutubePopoverManager.swift
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
import SwiftUI

protocol PrivateYoutubePopoverManagerDelegate: AnyObject {
    func privateYoutubePopoverManager(_ popover: PrivateYoutubePopoverManager, didEnable enabled: Bool)
}

final class PrivateYoutubePopoverManager: NSPopover {
    weak var statusDelegate: PrivateYoutubePopoverManagerDelegate?

    override init() {
        super.init()
        
        self.behavior = .semitransient
        
        setupContentController()
    }
    
    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }
    
    private func setupContentController() {
        contentViewController = PrivateYoutubePopoverViewController(enablePrivateYoutube: { [weak self] enabled in
            guard let self = self else { return }
            self.statusDelegate?.privateYoutubePopoverManager(self, didEnable: enabled)
        })
    }
}

final class PrivateYoutubePopoverViewController: NSViewController {
    let enablePrivateYoutube: (Bool) -> Void

    internal init(enablePrivateYoutube: @escaping (Bool) -> Void) {
        self.enablePrivateYoutube = enablePrivateYoutube
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = NSHostingView(rootView: PrivateYoutubeDiscoveryView(completion: enablePrivateYoutube))
            // workaround to fix a popover positioning issue
        view.frame = CGRect(x: 0, y: 0, width: 440, height: 170)
    }
}
