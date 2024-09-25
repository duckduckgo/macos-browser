//
//  WKPDFHUDViewWrapper.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Foundation
import WebKit

/// A wrapper for the PDF HUD window with Zoom controls, Download and Open in Preview buttons
/// Used to trigger Save PDF
struct WKPDFHUDViewWrapper {

    static let WKPDFHUDViewClass: AnyClass? = NSClassFromString("WKPDFHUDView")
    static let performActionForControlSelector = NSSelectorFromString("_performActionForControl:")
    static let visibleKey = "_visible"
    static let setVisibleSelector = NSSelectorFromString("_setVisible:")

    private enum ControlId: String {
        case savePDF = "arrow.down.circle"
        case zoomIn = "plus.magnifyingglass"
        case zoomOut = "minus.magnifyingglass"
    }

    private let hudView: NSView

    var isVisible: Bool {
        get {
            hudView.layer?.sublayers?.first?.opacity ?? 0 > 0
        }
        nonmutating set {
            guard hudView.responds(to: Self.setVisibleSelector) else { return }
            hudView.perform(Self.setVisibleSelector, with: newValue)
        }
    }

    /// Create a wrapper over the PDF HUD view validating its class is `WKPDFHUDView`
    /// - parameter view: the WKPDFHUDView to wrap
    /// - returns nil if the view
    init?(view: NSView) {
        guard type(of: view) == Self.WKPDFHUDViewClass else { return nil }

        guard Self.WKPDFHUDViewClass?.instancesRespond(to: Self.performActionForControlSelector) == true else {
            assertionFailure("WKPDFHUDView doesn‘t respond to _performActionForControl:")
            return nil
        }
        self.hudView = view
    }

    /// Find WebView‘s PDF HUD view at a clicked point
    /// 
    /// Used to get PDF controls view of a clicked WebView frame for `Print…` and `Save As…` PDF context menu commands
    static func getPdfHudView(in webView: WKWebView, at location: NSPoint? = nil) -> Self? {
        guard let hudView = webView.subviews.last(where: { type(of: $0) == Self.WKPDFHUDViewClass && $0.frame.contains(location ?? $0.frame.origin) }) else {
#if DEBUG
            Task {
                if await webView.mimeType == "application/pdf" {
                    assertionFailure("WebView doesn‘t have PDF HUD View")
                }
            }
#endif
            return nil
        }
        return self.init(view: hudView)
    }

    func savePDF() {
        performAction(for: .savePDF)
    }

    func zoomIn() {
        performAction(for: .zoomIn)
    }

    func zoomOut() {
        performAction(for: .zoomOut)
    }

    private func performAction(for controlId: ControlId) {
        let wasVisible = isVisible
        self.setIsVisibleIVar(true)
        defer {
            if !wasVisible {
                self.setIsVisibleIVar(false)
            }
        }
        hudView.perform(Self.performActionForControlSelector, with: controlId.rawValue)
    }

    // try to set _visible ivar value directly to avoid actually showing the HUD
    private func setIsVisibleIVar(_ value: Bool) {
        do {
            try NSException.catch {
                hudView.setValue(value, forKey: Self.visibleKey)
            }
        } catch {
            assertionFailure("\(error)")
            self.isVisible = value
        }
    }

}
