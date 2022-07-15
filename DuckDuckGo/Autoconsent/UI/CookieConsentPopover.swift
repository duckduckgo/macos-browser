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

protocol CookieConsentPopoverDelegate: AnyObject {
    func cookieConsentPopover(_ popOver: CookieConsentPopover, didFinishWithResult result: Bool)
}

public final class CookieConsentPopover {
    weak var delegate: CookieConsentPopoverDelegate?
    public var viewController: CookieConsentUserPermissionViewController
    public var windowController: NSWindowController

    public init() {
        let storyboard = NSStoryboard(name: "CookieConsent", bundle: Bundle.main)
        viewController = storyboard.instantiateController(identifier: "CookieConsentUserPermissionViewController")
        windowController = storyboard.instantiateController(identifier: "CookieConsentWindowController")
        
        windowController.contentViewController = viewController
        windowController.window?.acceptsMouseMovedEvents = true
        windowController.window?.ignoresMouseEvents = false
        
        viewController.view.window?.backgroundColor = .clear
        viewController.view.wantsLayer = true
        
        viewController.delegate = self
    }
    
    public func close(animated: Bool) {
        guard let overlayWindow = windowController.window else {
            return
        }
        if !overlayWindow.isVisible { return }
        
        let removeWindow = {
            overlayWindow.parent?.removeChildWindow(overlayWindow)
            overlayWindow.orderOut(nil)
        }
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.8
                overlayWindow.animator().alphaValue = 0
            } completionHandler: {
                removeWindow()
            }
        } else {
            removeWindow()
        }
    }
    
    public func show(on currentTabView: NSView, animated: Bool) {
        guard let currentTabViewWindow = currentTabView.window,
        let overlayWindow = windowController.window else {
            return
        }
        currentTabViewWindow.addChildWindow(overlayWindow, ordered: .above)
        
        let xPosition = (currentTabViewWindow.frame.width / 2) - (overlayWindow.frame.width / 2) + currentTabViewWindow.frame.origin.x
        let yPosition = currentTabViewWindow.frame.origin.y + currentTabViewWindow.frame.height - overlayWindow.frame.height
        let yPositionOffset: CGFloat = 65
        
        if animated {
            overlayWindow.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
            overlayWindow.alphaValue = 0
        
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.8
                let newOrigin = NSPoint(x: xPosition, y: yPosition - yPositionOffset)
                let size = overlayWindow.frame.size
                overlayWindow.animator().alphaValue = 1
                overlayWindow.animator().setFrame(NSRect(origin: newOrigin, size: size), display: true)

            } completionHandler: {
                self.viewController.startAnimation()
            }

        } else {
            overlayWindow.setFrameOrigin(NSPoint(x: xPosition, y: yPosition - yPositionOffset))
        }
    }
    
    public required init?(coder: NSCoder) {
        fatalError("CookieConsentPopover: Bad initializer")
    }
}

extension CookieConsentPopover: CookieConsentUserPermissionViewControllerDelegate {
    func cookieConsentUserPermissionViewController(_ controller: CookieConsentUserPermissionViewController, didFinishWithResult result: Bool) {
        self.delegate?.cookieConsentPopover(self, didFinishWithResult: result)
    }
}
