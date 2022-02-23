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

public final class ContentOverlayPopover {
    
    public var zoomFactor: CGFloat?

    public var viewController: ContentOverlayViewController?
    public var windowController: NSWindowController?
    
    public init() {
        let storyboard = NSStoryboard(name: "ContentOverlay", bundle: Bundle.main)
        viewController = storyboard
            .instantiateController(withIdentifier: "ContentOverlayViewController") as? ContentOverlayViewController
        windowController = storyboard
            .instantiateController(withIdentifier: "ContentOverlayWindowController") as? NSWindowController
        if let windowController = windowController {
            windowController.contentViewController = viewController
            windowController.window?.hasShadow = true
            windowController.window?.acceptsMouseMovedEvents = true
            windowController.window?.ignoresMouseEvents = false
        }
        
        viewController?.view.wantsLayer = true
        if let layer = viewController?.view.layer {
            layer.masksToBounds = true
            layer.cornerRadius = 6
            layer.borderWidth = 0.5
            layer.borderColor = CGColor.init(gray: 0, alpha: 0.3) // Looks a little lighter than 0.2 in the CSS
        }
        viewController?.view.window?.backgroundColor = .clear
        viewController?.view.window?.acceptsMouseMovedEvents = true
        viewController?.view.window?.ignoresMouseEvents = false
    }

    public required init?(coder: NSCoder) {
        fatalError("ContentOverlayPopover: Bad initializer")
    }
}

// AutofillOverlayDelegate
extension ContentOverlayPopover: ChildOverlayAutofillUserScriptDelegate {
    public var view: NSView {
        return viewController!.view
    }
    
    public func autofillCloseOverlay(_ autofillUserScript: AutofillMessagingToChildDelegate?) {
        guard let windowController = windowController?.window else {
            return
        }
        if !windowController.isVisible { return }
        // Reset window size on close to reduce flicker
        viewController?.requestResizeToSize(width: 0, height: 0)
        windowController.parent?.removeChildWindow(windowController)
        windowController.orderOut(nil)
    }

    public func autofillDisplayOverlay(_ autofillUserScript: AutofillMessagingToChildDelegate,
                                       of: NSView,
                                       serializedInputContext: String,
                                       click: NSPoint,
                                       inputPosition: CGRect) {
        // Combines native click with offset of JS click.
        let y = (click.y - (inputPosition.height - inputPosition.minY))
        let x = (click.x - inputPosition.minX)
        var rectWidth = inputPosition.width
        // If the field is wider we want to left assign the rectangle anchoring
        if inputPosition.width > 315 {
            rectWidth = 315
        }
        let rect = NSRect(x: x, y: y, width: rectWidth, height: inputPosition.height)

        // On open initialize to default size to reduce flicker
        viewController?.requestResizeToSize(width: 0, height: 0)
        viewController?.autofillInterfaceToChild = autofillUserScript
        viewController?.setType(serializedInputContext: serializedInputContext, zoomFactor: zoomFactor)
        if let window = windowController?.window {
            of.window!.addChildWindow(window, ordered: .above)
            let outRect = of.window!.convertToScreen(rect)
            window.setFrameTopLeftPoint(NSPoint(x: outRect.minX, y: outRect.minY))
        }
    }

}
