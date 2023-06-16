//
//  ContentOverlayPopover.swift
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
import WebKit
import BrowserServicesKit
import DependencyInjection
#if swift(>=5.9)
@Injectable
#endif
@MainActor
final class ContentOverlayPopover: Injectable {
    let dependencies: DependencyStorage

    typealias InjectedDependencies = ContentOverlayViewController.Dependencies

    var zoomFactor: CGFloat?
    weak var currentTabView: NSView?

    var viewController: ContentOverlayViewController
    var windowController: NSWindowController

    init(currentTabView: NSView, dependencyProvider: DependencyProvider) {
        dependencies = .init(dependencyProvider)

        let storyboard = NSStoryboard(name: "ContentOverlay", bundle: Bundle.main)
        viewController = storyboard.instantiateController(identifier: "ContentOverlayViewController") { [dependencies] coder in
            ContentOverlayViewController(coder: coder, dependencyProvider: dependencies)
        }
        windowController = storyboard.instantiateController(identifier: "ContentOverlayWindowController")
        windowController.contentViewController = viewController
        windowController.window?.hasShadow = true
        windowController.window?.acceptsMouseMovedEvents = true
        windowController.window?.ignoresMouseEvents = false

        viewController.view.wantsLayer = true
        if let layer = viewController.view.layer {
            layer.masksToBounds = true
            layer.cornerRadius = 6
            layer.borderWidth = 0.5
            layer.borderColor = CGColor.init(gray: 0, alpha: 0.3) // Looks a little lighter than 0.2 in the CSS
        }
        viewController.view.window?.backgroundColor = .clear
        viewController.view.window?.acceptsMouseMovedEvents = true
        viewController.view.window?.ignoresMouseEvents = false

        windowController.contentViewController = viewController

        self.currentTabView = currentTabView
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }
}

// MARK: - WebsiteAutofillUserScriptDelegate
extension ContentOverlayPopover: ContentOverlayUserScriptDelegate {
    public func websiteAutofillUserScriptCloseOverlay(_ websiteAutofillUserScript: WebsiteAutofillUserScript?) {
        guard let windowController = windowController.window else {
            return
        }
        if !windowController.isVisible { return }
        // Reset window size on close to reduce flicker
        viewController.requestResizeToSize(CGSize(width: 0, height: 0))
        windowController.parent?.removeChildWindow(windowController)
        windowController.orderOut(nil)
    }

    public func websiteAutofillUserScript(_ websiteAutofillUserScript: WebsiteAutofillUserScript,
                                          willDisplayOverlayAtClick: NSPoint?,
                                          serializedInputContext: String,
                                          inputPosition: CGRect) {
        guard let overlayWindow = windowController.window,
              let currentTabView = currentTabView,
              let currentTabViewWindow = currentTabView.window else {
                  return
              }
        var y = inputPosition.maxY
        var x = inputPosition.minX
        // Combines native click with offset of JS click.
        if let willDisplayOverlayAtClick = willDisplayOverlayAtClick {
            y = willDisplayOverlayAtClick.y - y
            x += willDisplayOverlayAtClick.x
        } else {
            y = currentTabView.frame.maxY - inputPosition.maxY
        }
        var rectWidth = inputPosition.width
        // If the field is wider we want to left assign the rectangle anchoring
        if inputPosition.width > 315 {
            rectWidth = 315
        }
        let rect = NSRect(x: x, y: y, width: rectWidth, height: inputPosition.height)

        viewController.autofillInterfaceToChild = websiteAutofillUserScript
        viewController.setType(serializedInputContext: serializedInputContext, zoomFactor: zoomFactor)

        currentTabViewWindow.addChildWindow(overlayWindow, ordered: .above)
        let outRect = currentTabViewWindow.convertToScreen(rect)
        overlayWindow.setFrameTopLeftPoint(NSPoint(x: outRect.minX, y: outRect.minY))
    }

}
