//
//  PreviewViewController.swift
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

import AppKit

@resultBuilder
struct NSViewBuilder {
    static func buildBlock(_ component: NSView) -> NSView {
        return component
    }
}

#if DEBUG
/// Used to preview an NSView using Xcode #Preview macro
/// Usage:
/// ```
/// @available(macOS 14.0, *)
/// #Preview {
///     PreviewViewController(showWindowTitle: false /*hide preview window title*/, adjustWindowFrame: true /*set the window size to the view size*/) {
///         MyNSView()
///     }
/// }
/// ```
@available(macOS 14.0, *)
final class PreviewViewController: NSViewController {
    let showWindowTitle: Bool
    let adjustWindowFrame: Bool

    init(showWindowTitle: Bool = true, adjustWindowFrame: Bool = false, @NSViewBuilder builder: () -> NSView) {
        self.showWindowTitle = showWindowTitle
        self.adjustWindowFrame = adjustWindowFrame
        super.init(nibName: nil, bundle: nil)
        self.view = builder()
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    override func viewDidAppear() {
        guard let window = view.window else { return }
        if !showWindowTitle {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask = []
        }
        if adjustWindowFrame {
            window.setFrame(NSRect(origin: .zero, size: view.bounds.size), display: true)
        }
    }

}
#else
final class PreviewViewController: NSViewController {
    init(showWindowTitle: Bool = true, adjustWindowFrame: Bool = false, @NSViewBuilder builder: () -> NSView) {
        fatalError("only for DEBUG")
    }
    required init?(coder: NSCoder) {
        fatalError("only for DEBUG")
    }
}
#endif
