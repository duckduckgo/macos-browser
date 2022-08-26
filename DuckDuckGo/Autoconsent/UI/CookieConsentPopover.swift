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

private enum AnimationConsts {
    static let yAnimationOffset: CGFloat = 65
    static let duration: CGFloat = 0.6
}

protocol CookieConsentPopoverDelegate: AnyObject {
    func cookieConsentPopover(_ popOver: CookieConsentPopover, didFinishWithResult result: Bool)
}

public final class CookieConsentPopover {
    weak var delegate: CookieConsentPopoverDelegate?
    public var viewController: CookieConsentUserPermissionViewController
    public var windowController: NSWindowController
    private var resizeObserver: Any?

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
    
    public func close(animated: Bool, completion: (() -> Void)? = nil) {
        guard let overlayWindow = windowController.window else {
            return
        }
        if !overlayWindow.isVisible { return }
        
        let removeWindow = {
            overlayWindow.parent?.removeChildWindow(overlayWindow)
            overlayWindow.orderOut(nil)
            completion?()
        }
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = AnimationConsts.duration
                
                let newOrigin = NSPoint(x: overlayWindow.frame.origin.x, y: overlayWindow.frame.origin.y + AnimationConsts.yAnimationOffset)
                let size = overlayWindow.frame.size
                overlayWindow.animator().alphaValue = 0
                overlayWindow.animator().setFrame(NSRect(origin: newOrigin, size: size), display: true)
            } completionHandler: {
                removeWindow()
            }
        } else {
            removeWindow()
        }
    }
    
    private func windowDidResize(_ parent: NSWindow) {
        guard let overlayWindow = windowController.window else {
            return
        }
        
        let xPosition = (parent.frame.width / 2) - (overlayWindow.frame.width / 2) + parent.frame.origin.x
        let yPosition = parent.frame.origin.y + parent.frame.height - overlayWindow.frame.height - AnimationConsts.yAnimationOffset

        let size = overlayWindow.frame.size
        let newOrigin = NSPoint(x: xPosition, y: yPosition)
        overlayWindow.setFrame(NSRect(origin: newOrigin, size: size), display: true)
    }
    
    private func addObserverForWindowResize(_ window: NSWindow) {
        resizeObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification,
                                                                object: window,
                                                                queue: .main) { [weak self] notification in
            guard let parent = notification.object as? NSWindow else { return }
            self?.windowDidResize(parent)
        }
    }
    
    public func show(on currentTabView: NSView, animated: Bool) {
        guard let currentTabViewWindow = currentTabView.window,
              let overlayWindow = windowController.window else {
            return
        }

        addObserverForWindowResize(currentTabViewWindow)
        
        currentTabViewWindow.addChildWindow(overlayWindow, ordered: .above)
        
        let xPosition = (currentTabViewWindow.frame.width / 2) - (overlayWindow.frame.width / 2) + currentTabViewWindow.frame.origin.x
        let yPosition = currentTabViewWindow.frame.origin.y + currentTabViewWindow.frame.height - overlayWindow.frame.height
        
        if animated {
            overlayWindow.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
            overlayWindow.alphaValue = 0
        
            NSAnimationContext.runAnimationGroup { context in
                context.duration = AnimationConsts.duration
                let newOrigin = NSPoint(x: xPosition, y: yPosition - AnimationConsts.yAnimationOffset)
                let size = overlayWindow.frame.size
                overlayWindow.animator().alphaValue = 1
                overlayWindow.animator().setFrame(NSRect(origin: newOrigin, size: size), display: true)

            } completionHandler: {
                self.viewController.startAnimation()
            }

        } else {
            overlayWindow.setFrameOrigin(NSPoint(x: xPosition, y: yPosition - AnimationConsts.yAnimationOffset))
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
