//
//  MainWindow.swift
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
import Combine

final class MainWindow: NSWindow {

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    var mainViewController: MainViewController? {
        guard let mainViewController = contentViewController as? MainViewController else {
            assertionFailure("Unexpected View Controller type")
            return nil
        }
        return mainViewController
    }

    init(frame: NSRect) {
        super.init(contentRect: frame,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: true)

        setupWindow()
    }

    private func setupWindow() {
        allowsToolTipsWhenApplicationIsInactive = false
        autorecalculatesKeyViewLoop = true
        isReleasedWhenClosed = false
        animationBehavior = .documentWindow
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        // the window will be draggable using custom drag areas defined by WindowDraggingView
        isMovable = false
    }

    // MARK: - First Responder Notification

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        guard self.firstResponder !== responder else { return true }
        // The only reliable way to detect NSTextField is the first responder
        defer {
            // Send it after the first responder has been set on the super class so that window.firstResponder matches correctly
            postFirstResponderNotification(with: responder)
        }
        
        return super.makeFirstResponder(responder)
    }

    override func becomeMain() {
        super.becomeMain()

        postFirstResponderNotification(with: firstResponder)
    }

    override func endEditing(for object: Any?) {
        if case .leftMouseUp = NSApp.currentEvent?.type,
           object is AddressBarTextEditor {
            // prevent deactivation of Address Bar on Toolbar click
            return
        }

        super.endEditing(for: object)
    }

    var cont: NSView!
    var frv: NSView?
    var c: Any?
    private func postFirstResponderNotification(with firstResponder: NSResponder?) {
        NotificationCenter.default.post(name: .firstResponder, object: firstResponder)
        // TODO: Endless loop if right-click Username field and then Tab // swiftlint:disable:this todo
        print("firstResponder", firstResponder)

        frv?.removeFromSuperview()
        c = nil
        if let firstResponder = firstResponder as? TabBarView {
//            firstResponder.highli

            let cframe = firstResponder.enclosingScrollView?.superview?
                .convert(firstResponder.enclosingScrollView!.frame, to: self.contentView!.superview!)
                .insetBy(dx: -2, dy: -6)
            if let cframe = cframe {
                if cont == nil {
                    let c = NSView(frame: cframe)
                    c.autoresizingMask = [.width]
                    c.wantsLayer = true
                    c.layer!.cornerRadius = 12.0
                    cont = c
                    self.contentView!.superview!.addSubview(c)
                }
                cont.frame = cframe
            }

            let shadow = ShadowView()
            shadow.stroke = 2
            frv = shadow

            let frame = (firstResponder as? NSView)!.bounds
            firstResponder.enclosingScrollView?.postsBoundsChangedNotifications = true
            c = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
                                                       object: firstResponder.enclosingScrollView?.contentView,
                                                       queue: nil) { [weak shadow, cont] _ in

                shadow?.frame = (firstResponder as? NSView)!.convert(frame, to: cont) // self.contentView!.superview!)
            }
            shadow.frame = (firstResponder as? NSView)!.convert(frame, to: cont) // self.contentView!.superview!)

            shadow.shadowColor = NSColor.controlAccentColor
            shadow.shadowRadius = 0
            shadow.cornerRadius = 6
            shadow.shadowOpacity = 1.0
            shadow.shouldHideOnLostFocus = true
//            frv?.strokedBackgroundColor = .clear
//            frv?.unstrokedBackgroundColor = .clear
//            self.contentView!.superview!.addSubview(frv!)
            cont.addSubview(shadow)

//            DispatchQueue.main.async {
//                self.frv!.updateView(stroke: true)
//            }

        }
    }
    @objc func handleEvent(_ event: NSEvent) -> Bool {
print(event)
        return true
    }

    var newTabButton: NSButton? {
        self.mainViewController?.tabBarViewController.addButton ??
            mainViewController?.tabBarViewController.plusButton
    }

    override func accessibilityChildren() -> [Any]? {
        var children = super.accessibilityChildren() as? [NSObject] ?? []
        let newTabButton = self.newTabButton
        if let newTabIdx = children.firstIndex(where: { $0 === newTabButton?.cell }) {
            children.remove(at: newTabIdx)
        }
        return children
    }
    
    // Handle Keyboard toggle Toolbar focus (Ctrl+F5)
    @objc(_handleFocusToolbarHotKey:)
    func handleFocusToolbarHotKey(_ event: Any?) {
        guard mainViewController?.children.isEmpty != false else {
            return
        }
        mainViewController?.toggleToolbarFocus()
    }

    override func recalculateKeyViewLoop() {
        mainViewController?.tabBarViewController.view.superview?.setDefaultKeyViewLoop()
        super.recalculateKeyViewLoop()

//        mainViewController?.navigationBarViewController.optionsButton.nextKeyView =
//            mainViewController?.tabBarViewController.collectionView.subviews.first
        // TODO: Need to iterate through collectionView.itemAtIndexPath because not all views are created // swiftlint:disable:this todo
        let cv = mainViewController!.tabBarViewController.collectionView!
        for idx in 0..<cv.numberOfItems(inSection: 0) {
            guard let item = (cv.item(at: idx) as? TabBarViewItem) else { continue }
            let subview = item.view
            if idx == 0 {
                mainViewController?.navigationBarViewController.optionsButton.nextKeyView = subview
            }
            let btns = subview.subviews.filter { $0 is NSButton }
            for (btnI, btn) in btns.enumerated() {
                if btnI == 0 {
                    subview.nextKeyView = btn
                } else {
                    btns[btnI - 1].nextKeyView = btn
                    if btns.count == btnI + 1 {
                        if let nextTab = (cv.item(at: idx + 1) as? TabBarViewItem)?.view as? TabBarView {
                            btn.nextKeyView = nextTab
                        } else {
                            btn.nextKeyView = self.newTabButton
                        }
                    }
                }
            }

        }
        self.newTabButton?.nextKeyView = mainViewController?.tabBarViewController.fireButton

//        let btns: [NSView] = [
//            self.mainViewController!.tabBarViewController.fireButton,
//            self.mainViewController!.navigationBarViewController.goBackButton,
//            self.mainViewController!.navigationBarViewController.goForwardButton,
//            self.mainViewController!.navigationBarViewController.refreshButton,
//            self.mainViewController!.navigationBarViewController.addressBarViewController!.addressBarButtonsViewController!.imageButton,
//            self.mainViewController!.navigationBarViewController.addressBarViewController!.addressBarTextField
//        ]
//
//        for (idx, btn) in btns.enumerated() {
//            if idx == btns.count - 1 {
//                btn.nextKeyView = self.mainViewController!.navigationBarViewController.optionsButton
//            } else {

//                btn.nextKeyView = btns[idx + 1]
//            }
//        }

        mainViewController?.tabBarViewController.fireButton.nextKeyView = self.mainViewController?.navigationBarViewController.goBackButton
//
//        self.mainViewController?.navigationBarViewController.goBackButton.nextKeyView = self.mainViewController?.navigationBarViewController.goForwardButton
//        self.mainViewController?.navigationBarViewController.goForwardButton.nextKeyView = self.mainViewController?.navigationBarViewController.refreshButton
//        self.mainViewController?.navigationBarViewController.refreshButton.nextKeyView = self.mainViewController?.navigationBarViewController.addressBarViewController?.addressBarTextField

//        mainViewController?.webContainerView.nextKeyView = mainViewController?.tabBarViewController.view
//        mainViewController?.tabBarViewController.view.nextKeyView = mainViewController?.navigationBarViewController.view.nextKeyView
    }

    @objc(_keyViewRedirectionDisabled)
    func keyViewRedirectionDisabled() -> Bool {
        true
    }

}

extension Notification.Name {
    static let firstResponder = Notification.Name("firstResponder")
}
