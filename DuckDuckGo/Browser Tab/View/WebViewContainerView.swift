//
//  WebViewContainerView.swift
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

import AppKit
import Combine

final class WebViewContainerView: NSView {
    private let stackView: NSStackView
    let webView: WebView
    private(set) weak var serpWebView: WebView?

    override var constraints: [NSLayoutConstraint] {
        // return nothing to WKFullScreenWindowController which will keep the constraints
        // and crash after trying to reactivate them as the ContainerView will be gone by the moment
        // and NSLayouConstraint has unsafe/unowned references to its views
        return []
    }

    func showSERPWebView(_ serpWebView: WebView) {
        self.serpWebView = serpWebView

        serpWebView.translatesAutoresizingMaskIntoConstraints = false
        serpWebView.removeConstraints(serpWebView.constraints)
        serpWebView.widthAnchor.constraint(equalToConstant: 720).isActive = true
        stackView.insertArrangedSubview(serpWebView.tabContentView, at: 0)
    }

    func hideSERPWebView() {
        serpWebView?.removeFromSuperview()
    }

    init(webView: WebView, frame: NSRect) {
        stackView = NSStackView()
        self.webView = webView
        super.init(frame: frame)

        self.autoresizingMask = [.width, .height]

        stackView.orientation = .horizontal
//        stackView.distribution = .fillEqually
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = true
        stackView.frame = bounds
        stackView.autoresizingMask = [.width, .height]
        addSubview(stackView)
        stackView.addArrangedSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var blurViewIsHiddenCancellable: AnyCancellable?
    override func didAddSubview(_ subview: NSView) {
        // if fullscreen placeholder is shown
        guard self.webView.tabContentView !== self.webView else { return }

        subview.frame = self.bounds
        // fix Inspector snapshot not being blurred completely on fullscreen enter
        if let blurView = subview.subviews.first(where: { $0 is NSVisualEffectView }),
           blurView.frame != subview.bounds {

            blurView.frame = subview.bounds
            // and fix the glitch
            blurView.isHidden = false
            // try softening the glitch on fullscreen exit
            blurViewIsHiddenCancellable = blurView.publisher(for: \.isHidden)
                .sink { [weak blurView] isHidden in
                    if isHidden {
                        blurView?.isHidden = false
                    }
                }
        }
    }

    override func removeFromSuperview() {
        self.webView.tabContentView.removeFromSuperview()
        super.removeFromSuperview()
    }

}

extension WebView {
    var containerView: WebViewContainerView? {
        superview as? WebViewContainerView ?? tabContentView.superview as? WebViewContainerView
    }
}
