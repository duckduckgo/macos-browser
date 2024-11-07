//
//  ExperimentalFeaturesMenu.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

final class ExperimentalFeaturesMenu: NSMenu {

    let experimentalFeatures: ExperimentalFeatures

    private(set) lazy var htmlNewTabPageMenuItem = NSMenuItem(title: "HTML New Tab Page", action: #selector(toggleHTMLNewTabPage(_:))).targetting(self)

    init(experimentalFeatures: ExperimentalFeatures) {
        self.experimentalFeatures = experimentalFeatures
        super.init(title: "")

        buildItems {
            htmlNewTabPageMenuItem
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update() {
        super.update()
        htmlNewTabPageMenuItem.state = NSApp.delegateTyped.experimentalFeatures.isHTMLNewTabPageEnabled ? .on : .off
    }

    @objc func toggleHTMLNewTabPage(_ sender: NSMenuItem) {
        experimentalFeatures.isHTMLNewTabPageEnabled.toggle()
    }
}
