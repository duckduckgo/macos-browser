//
//  Application.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

@objc(Application)
final class Application: NSApplication {

    private let copyHandler = CopyHandler()
    private var _delegate: AppDelegate!

    override init() {
        super.init()

        _delegate = AppDelegate()
        self.delegate = _delegate

        let mainMenu = MainMenu(featureFlagger: _delegate.featureFlagger,
                                bookmarkManager: _delegate.bookmarksManager,
                                faviconManager: FaviconManager.shared,
                                copyHandler: copyHandler)
        self.mainMenu = mainMenu

        // Makes sure Spotlight search is part of Help menu
        self.helpMenu = mainMenu.helpMenu
        self.windowsMenu = mainMenu.windowsMenu
        self.servicesMenu = mainMenu.servicesMenu
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

}
