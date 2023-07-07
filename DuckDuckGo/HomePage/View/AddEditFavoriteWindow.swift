//
//  AddEditFavoriteWindow.swift
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

final class AddEditFavoriteWindow: NSWindow {

    static var contentRect: NSRect {
        let width: CGFloat = 450
        let height: CGFloat = 175
        let screenFrame = NSScreen.main?.frame ?? .init(x: 0, y: 0, width: 1280, height: 960)
        return NSRect(x: screenFrame.origin.x + screenFrame.size.width / 2.0 - width / 2.0,
                      y: screenFrame.origin.y + screenFrame.size.height / 2.0 - height / 2.0,
                      width: width,
                      height: height)
    }

    override var canBecomeMain: Bool { false }

    var addEditFavoriteViewController: AddEditFavoriteViewController {
        contentViewController as! AddEditFavoriteViewController // swiftlint:disable:this force_cast
    }

    init(dependencyProvider: AddEditFavoriteViewController.DependencyProvider, bookmark: Bookmark? = nil) {
        super.init(contentRect: Self.contentRect, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: true)

        self.contentViewController = NSStoryboard(name: "HomePage", bundle: .main)
            .instantiateController(identifier: AddEditFavoriteViewController.className()) { coder in
                AddEditFavoriteViewController(coder: coder, dependencyProvider: dependencyProvider, bookmark: bookmark)
            }
    }

}
