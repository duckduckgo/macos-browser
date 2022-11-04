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

        serpWebView.translatesAutoresizingMaskIntoConstraints = true
        serpWebView.autoresizingMask = [.height]

        var frame = bounds
        frame.size.width = 720
        frame.origin.x = -720
        serpWebView.frame = frame
        addSubview(serpWebView, positioned: .below, relativeTo: webView)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true

            webView.frame.origin.x += 720
            webView.frame.size.width = bounds.width - 720
            serpWebView.frame.origin.x = 0
        }) {
            self.needsCustomLayout = true
        }
    }

    func hideSERPWebView() {

        guard let serpWebView else {
            return
        }

        self.needsCustomLayout = false

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true

            serpWebView.frame.origin.x -= 720
            webView.frame = bounds
        }) {
            serpWebView.removeFromSuperview()
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
            webView.frame.size.width = bounds.size.width - 720
            webView.frame.origin.x = 720
        }
    }

}

extension WebView {
    var containerView: WebViewContainerView? {
        superview as? WebViewContainerView ?? tabContentView.superview as? WebViewContainerView
    }
}
