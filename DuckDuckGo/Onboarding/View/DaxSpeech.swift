//
//  DaxSpeech.swift
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

import SwiftUI
import Combine

extension Onboarding {

struct DaxSpeech: View {

    @EnvironmentObject var model: OnboardingViewModel

    // @Binding var typingFinished: Bool

    let text: String

    let onTypingFinished: (() -> Void)?

    @State private var typingIndex = 0
    @State private var typedText = ""
    @State private var timer = Timer.publish(every: 0.03, tolerance: 0, on: .main, in: .default, options: nil).autoconnect()

    var body: some View {
        ZStack(alignment: .topLeading) {

            // This text view sets the proper height for the speech bubble.
            Text(text)
                .kerning(-0.23)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .visibility(.invisible)

            Text(typedText)
                .kerning(-0.23)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .lineLimit(nil)
        .multilineTextAlignment(.leading)
        .font(.system(size: 15))
        .lineSpacing(9)
        .frame(width: 328)
        .background(SpeechBubble())
        .onReceive(timer, perform: { _ in
            if model.skipTypingRequested {
                typedText = text
                model.typingSkipped()
            }

            if typedText == text {
                onTypingFinished?()
                self.timer.upstream.connect().cancel()
                return
            }
            
            typingIndex = min(typingIndex + 1, text.utf16.count)
            typedText = String(text.utf16[text.utf16.startIndex ..< text.utf16.index(text.utf16.startIndex, offsetBy: typingIndex)]) ?? ""
        })
    }

}

fileprivate struct SpeechBubble: View {

    let radius: CGFloat = 8
    let tailSize: CGFloat = 8
    let tailPosition: CGFloat = 32

    var body: some View {
        ZStack {
            GeometryReader { g in
                let rect = CGRect(x: 0, y: 0, width: g.size.width, height: g.size.height)

                Path { path in

                    path.move(to: CGPoint(x: rect.minX, y: rect.maxY - radius))

                    path.addLine(to: CGPoint(x: rect.minX, y: tailPosition + 10))
                    path.addLine(to: CGPoint(x: rect.minX - tailSize, y: tailPosition))
                    path.addLine(to: CGPoint(x: rect.minX, y: tailPosition - 10))

                     path.addArc(
                         center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                         radius: radius,
                         startAngle: .degrees(180),
                         endAngle: .degrees(270),
                         clockwise: false
                     )
                     path.addArc(
                         center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                         radius: radius,
                         startAngle: .degrees(270),
                         endAngle: .degrees(0),
                         clockwise: false
                     )
                     path.addArc(
                         center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                         radius: radius,
                         startAngle: .degrees(0),
                         endAngle: .degrees(90),
                         clockwise: false
                     )
                     path.addArc(
                         center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                         radius: radius,
                         startAngle: .degrees(90),
                         endAngle: .degrees(180),
                         clockwise: false
                     )

                }
                .fill(Color(NSColor.interfaceBackgroundColor))
                .shadow(radius: 5)
            }

        }
    }
}

}
