//
//  MainWindowController.swift
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
import os.log

final class MainWindowController: NSWindowController {
    static let windowFrameSaveName = "MainWindow"

    var mainViewController: MainViewController {
        // swiftlint:disable force_cast
        contentViewController as! MainViewController
        // swiftlint:enable force_cast
    }

    var tabCollectionViewModel: TabCollectionViewModel {
        mainViewController.tabCollectionViewModel
    }

    required init?(coder: NSCoder) {
        fatalError("MainWindowController: Bad initializer")
    }

    enum WindowPosition: Equatable {
        case auto
        case origin(NSPoint)
        case droppingPoint(NSPoint)
    }

    init(tabCollectionViewModel: TabCollectionViewModel,
         position: WindowPosition,
         contentSize: NSSize?) {

        let mainViewController = NSStoryboard.main.instantiateController(identifier: .mainViewController) { coder in
            MainViewController(coder: coder, tabCollectionViewModel: tabCollectionViewModel)!
        }

        let window = MainWindow()
        window.contentViewController = mainViewController

        super.init(window: window)

        setupWindow(position: position, contentSize: contentSize)
    }

    private func setupWindow(position: WindowPosition, contentSize: NSSize?) {
        window!.delegate = self

        if contentSize == nil || position == .auto {
            // adjust using last saved frame
            window!.setFrameUsingName(Self.windowFrameSaveName)
        }
        if let contentSize = contentSize {
            window!.setContentSize(contentSize)
        }

        switch position {
        case .droppingPoint(let point):
            let origin = window!.frameOrigin(fromDroppingPoint: point)
            window!.setFrameOrigin(origin)
        case .origin(let origin):
            window!.setFrameOrigin(origin)
        case .auto:
            // cascade windows from the last saved frame
            var origin = window!.frame.origin
            origin.y += window!.frame.size.height
            origin = window!.cascadeTopLeft(from: origin)
            origin.y -= window!.frame.size.height
            window!.setFrameOrigin(origin)
        }

        window!.saveFrame(usingName: Self.windowFrameSaveName)
    }

    override func showWindow(_ sender: Any?) {
        window!.makeKeyAndOrderFront(sender)
        WindowControllersManager.shared.register(self)
    }

}

extension MainWindowController: NSWindowDelegate {

    func windowDidResize(_ notification: Notification) {
        window!.saveFrame(usingName: Self.windowFrameSaveName)
    }

    func windowDidMove(_ notification: Notification) {
        window!.saveFrame(usingName: Self.windowFrameSaveName)
    }

    func windowDidBecomeMain(_ notification: Notification) {
        mainViewController.windowDidBecomeMain()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        WindowControllersManager.shared.lastKeyMainWindowController = self
    }

    func windowWillClose(_ notification: Notification) {
        mainViewController.windowWillClose()
        WindowControllersManager.shared.unregister(self)
    }

}

fileprivate extension NSStoryboard.SceneIdentifier {
    static let mainViewController = NSStoryboard.SceneIdentifier("mainViewController")
}
