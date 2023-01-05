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

final class SwipeGestureView: NSView {

    enum Direction: Equatable {
        case back, forward
    }

    override init(frame frameRect: NSRect) {
        gestureEventPublisher = gestureEventSubject.eraseToAnyPublisher()
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        gestureEventPublisher = gestureEventSubject.eraseToAnyPublisher()
        super.init(coder: coder)
    }

    let gestureEventPublisher: AnyPublisher<Direction, Never>

    private let gestureEventSubject = PassthroughSubject<Direction, Never>()
    private var distance: CGSize = .zero
    private var isTrackingSwipe = false

    override func scrollWheel(with event: NSEvent) {
        switch event.momentumPhase {
        case .began:
            distance = .zero
            isTrackingSwipe = true
        case .changed:
            if isTrackingSwipe {
                distance.width += event.scrollingDeltaX
                distance.height += event.scrollingDeltaY
                if abs(distance.width) > 100 && abs(distance.width) > abs(distance.height) {
                    isTrackingSwipe = false
                    gestureEventSubject.send(distance.width > 0 ? .back : .forward)
                }
            }
        default:
            break
        }
        super.scrollWheel(with: event)
    }
}

final class WebViewContainerView: NSView {
    let webView: WebView
    let swipeGestureView: SwipeGestureView

    enum Const {
        static let serpPanelWidth: CGFloat = 520
    }

    private lazy var lightShadowView = {
        let view = ShadowView()
        view.autoresizingMask = [.width, .height]
        view.shadowSides = .left
        view.shadowOpacity = 1
        view.shadowColor = .init(white: 0, alpha: 0.08)
        view.shadowOffset = .init(width: 0, height: 20)
        view.shadowRadius = 40
        return view
    }()

    private lazy var darkShadowView = {
        let view = ShadowView()
        view.autoresizingMask = [.width, .height]
        view.shadowSides = .left
        view.shadowOpacity = 1
        view.shadowColor = .init(white: 0, alpha: 0.1)
        view.shadowOffset = .init(width: 0, height: 4)
        view.shadowRadius = 12
        return view
    }()

    private(set) weak var serpWebView: WebView?
    private var needsCustomLayout: Bool = false

    override var constraints: [NSLayoutConstraint] {
        // return nothing to WKFullScreenWindowController which will keep the constraints
        // and crash after trying to reactivate them as the ContainerView will be gone by the moment
        // and NSLayouConstraint has unsafe/unowned references to its views
        return []
    }

    func showSERPWebView(_ serpWebView: WebView) {
        guard self.serpWebView == nil else {
            return
        }

        self.serpWebView = serpWebView
        darkShadowView.alphaValue = 0
        lightShadowView.alphaValue = 0

        serpWebView.translatesAutoresizingMaskIntoConstraints = true
        serpWebView.autoresizingMask = [.height]

        var frame = bounds
        frame.size.width = Const.serpPanelWidth
        frame.origin.x = -Const.serpPanelWidth
        serpWebView.frame = frame
        addSubview(serpWebView, positioned: .below, relativeTo: webView)
        addSubview(darkShadowView, positioned: .below, relativeTo: webView)
        addSubview(lightShadowView, positioned: .below, relativeTo: darkShadowView)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true

            webView.frame.origin.x += Const.serpPanelWidth
            serpWebView.frame.origin.x = 0
            darkShadowView.frame = webView.frame
            lightShadowView.frame = webView.frame
            darkShadowView.alphaValue = 1
            lightShadowView.alphaValue = 1
        }) {
            self.needsCustomLayout = true
        }
    }

    func resizeWebViewToFitScreenAndSERPPanel() {
        let targetWidth = bounds.width - Const.serpPanelWidth

        guard needsCustomLayout, webView.frame.width != targetWidth else {
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true

            webView.frame.size.width = bounds.width - Const.serpPanelWidth
        })
    }

    func hideSERPWebView() {

        guard let serpWebView else {
            return
        }

        self.needsCustomLayout = false

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true

            serpWebView.frame.origin.x -= Const.serpPanelWidth
            webView.frame = bounds
            darkShadowView.alphaValue = 0
            lightShadowView.alphaValue = 0
        }) {
            serpWebView.removeFromSuperview()
            self.darkShadowView.removeFromSuperview()
            self.lightShadowView.removeFromSuperview()
            self.serpWebView = nil
        }
    }

    init(webView: WebView, frame: NSRect) {
        self.webView = webView
        swipeGestureView = SwipeGestureView()
        super.init(frame: frame)

        self.autoresizingMask = [.width, .height]
        swipeGestureView.autoresizingMask = [.width, .height]
        swipeGestureView.frame = bounds

        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.width, .height]
        webView.frame = bounds
        addSubview(webView)
        addSubview(swipeGestureView)
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

    override func layout() {
        super.layout()

        if needsCustomLayout {
            webView.frame.origin.x = Const.serpPanelWidth
            darkShadowView.frame = webView.frame
            lightShadowView.frame = webView.frame
        }
    }

}

extension WebView {
    var containerView: WebViewContainerView? {
        superview as? WebViewContainerView ?? tabContentView.superview as? WebViewContainerView
    }
}
