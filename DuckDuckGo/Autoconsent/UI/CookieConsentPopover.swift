//
//  CookieConsentPopover.swift
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

import Cocoa

public final class CookieConsentPopover {
    
    public var viewController: CookieConsentUserPermissionViewController
    public var windowController: NSWindowController
    public weak var currentTabView: NSView?

    public init(currentTabView: NSView) {
        let storyboard = NSStoryboard(name: "CookieConsent", bundle: Bundle.main)
        viewController = storyboard.instantiateController(identifier: "CookieConsentUserPermissionViewController")
        windowController = storyboard.instantiateController(identifier: "CookieConsentWindowController")
        windowController.contentViewController = viewController
      //  windowController.window?.hasShadow = true
        windowController.window?.acceptsMouseMovedEvents = true
        windowController.window?.ignoresMouseEvents = false
        
        viewController.view.window?.backgroundColor = .clear
        viewController.view.wantsLayer = true
        self.currentTabView = currentTabView

    }
    
    public func show() {
        guard let currentTabView = currentTabView,
        let currentTabViewWindow = currentTabView.window,
        let overlayWindow = windowController.window else {
            return
        }
        currentTabViewWindow.addChildWindow(overlayWindow, ordered: .above)
        
        let xPosition = (currentTabViewWindow.frame.width / 2) - (overlayWindow.frame.width / 2) + currentTabViewWindow.frame.origin.x
        var yPosition = currentTabViewWindow.frame.origin.y + currentTabViewWindow.frame.height - overlayWindow.frame.height

        overlayWindow.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
        overlayWindow.alphaValue = 0

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.8
            yPosition -= 65
            
            let newOrigin = NSPoint(x: xPosition, y: yPosition)
            let size = overlayWindow.frame.size
            overlayWindow.animator().alphaValue = 1
            overlayWindow.animator().setFrame(NSRect(origin: newOrigin, size: size), display: true)
        }) {
            // no-op
        }
    }
    
    public required init?(coder: NSCoder) {
        fatalError("CookieConsentPopover: Bad initializer")
    }
}
