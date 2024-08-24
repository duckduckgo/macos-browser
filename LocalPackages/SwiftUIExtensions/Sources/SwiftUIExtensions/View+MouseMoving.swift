//
//  View+MouseMoving.swift
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

import SwiftUI

public extension View {
    func onMouseMoving(perform action: @escaping () -> Void) -> some View {
        modifier(MouseMovingModifier(action))
    }
}

private struct MouseMovingModifier: ViewModifier {
    let isMoving: () -> Void

    init(_ isMoving: @escaping () -> Void) {
        self.isMoving = isMoving
    }

    func body(content: Content) -> some View {
        content.background(
            GeometryReader(content: { proxy in
                TrackingAreaRepresentable(isMoving: isMoving, frame: proxy.frame(in: .global))
            })
        )
    }
}

private extension MouseMovingModifier {

    struct TrackingAreaRepresentable: NSViewRepresentable {
        let isMoving: () -> Void
        let frame: CGRect

        func makeCoordinator() -> Coordinator {
            Coordinator(isMoving: isMoving)
        }

        func makeNSView(context: Context) -> NSView {
            let view = NSView(frame: frame)

            let options: NSTrackingArea.Options = [
                .mouseMoved,
                .inVisibleRect,
                .activeInKeyWindow
            ]

            let trackingArea = NSTrackingArea(
                rect: frame,
                options: options,
                owner: context.coordinator,
                userInfo: nil
            )

            view.addTrackingArea(trackingArea)
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {}

        static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
            nsView.trackingAreas.forEach(nsView.removeTrackingArea(_:))
        }
    }

    final class Coordinator: NSResponder {
        var isMoving: () -> Void

        init(isMoving: @escaping () -> Void) {
            self.isMoving = isMoving
            super.init()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func mouseMoved(with event: NSEvent) {
            isMoving()
        }
    }

}
