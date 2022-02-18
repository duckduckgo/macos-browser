//
//  ContentOverlayPopover.swift
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
import WebKit
import BrowserServicesKit

// Extends to override canBecomeKey
final class MyPanel: NSWindow {
    override var canBecomeKey: Bool {
        get {
            return true
        }
    }
    override var canBecomeMain: Bool {
        get {
            return false
        }
    }
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        self.styleMask.remove(.titled)
        self.styleMask.insert(.borderless)
        self.styleMask.remove(.nonactivatingPanel)
        self.appearance = NSAppearance(named: NSAppearance.Name.vibrantLight)
        self.makeKeyAndOrderFront(self)
        self.backgroundColor = .clear
        //self.isFloatingPanel = true
        //self.becomesKeyOnlyIfNeeded = true
        self.acceptsMouseMovedEvents = true
    }
}

public final class ContentOverlayPopover {
    
    public var zoomFactor: CGFloat?

    public var viewController: ContentOverlayViewController?
    public var windowController: NSWindowController?
    public var messageInterfaceBack: AutofillMessaging?
    
    public init() {
        let storyboard = NSStoryboard(name: "ContentOverlay", bundle: Bundle.main)
        viewController = storyboard
            .instantiateController(withIdentifier: "ContentOverlayViewController") as? ContentOverlayViewController
        windowController = storyboard
            .instantiateController(withIdentifier: "ContentOverlayWindowController") as? NSWindowController
        windowController?.contentViewController = viewController
        
        viewController?.view.wantsLayer = true
        if let layer = viewController?.view.layer {
            layer.masksToBounds = true
            layer.cornerRadius = 6
            layer.borderWidth = 0.5
            layer.borderColor = CGColor.init(gray: 0, alpha: 0.3) // Looks a little lighter than 0.2 in the CSS
            
            // box-shadow: rgba(0, 0, 0, 0.32) 0px 10px 20px;
            /*
            layer.shadowOffset = CGSize(width: -10, height: -20)
            layer.shadowRadius = 10
            layer.shadowColor = CGColor.init(gray: 0, alpha: 1)
            layer.shadowOpacity = 1.0
            */
        }
        
        print("TODOJKT .... color \(viewController?.view.layer?.borderColor)")
        viewController?.view.window?.backgroundColor = .clear
        viewController?.view.window?.acceptsMouseMovedEvents = true
        viewController?.view.window?.ignoresMouseEvents = false
        windowController?.window?.acceptsMouseMovedEvents = true
        windowController?.window?.ignoresMouseEvents = false
    }

    public required init?(coder: NSCoder) {
        fatalError("ContentOverlayPopover: Bad initializer")
    }
    
    public func close() {
        guard let windowController = windowController?.window else {
            return
        }
        if !windowController.isVisible { return }
        // Reset window size on close to reduce flicker
        viewController?.setSize(height: 0, width: 0)
        windowController.parent?.removeChildWindow(windowController)
        windowController.orderOut(nil)
    }
    
    public func display(rect: NSRect, of: NSView, width: CGFloat, inputType: String, messageInterface: AutofillMessaging) {
        messageInterfaceBack = messageInterface
        viewController?.messageInterfaceBack = messageInterfaceBack
        viewController?.setType(inputType: inputType, zoomFactor: zoomFactor)
        if let window = windowController?.window {
            of.window!.addChildWindow(window, ordered: .above)
            let outRect = of.window!.convertToScreen(rect)
            window.setFrameTopLeftPoint(NSPoint(x: outRect.minX, y: outRect.minY))
        }
    }

}
