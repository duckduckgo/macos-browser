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
import SwiftUIExtensions

extension Onboarding {

struct DaxSpeech: View {

    @EnvironmentObject var model: OnboardingViewModel

    let text: String

    let onTypingFinished: (() -> Void)?

    @State private var typingIndex = 0
    @State private var typedText = "" {
        didSet {
            guard #available(macOS 12, *) else { return }
            let chars = Array(text)
            let untypedChars = chars[Array(typedText).count ..< chars.count]
            let combined = NSMutableAttributedString(string: typedText)
            combined.append(NSAttributedString(string: String(untypedChars), attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.clear
            ]))
            attributedTypedText = combined
        }
    }
    @State private var timer = Timer.publish(every: 0.02, tolerance: 0, on: .main, in: .default, options: nil).autoconnect()

    @State private var attributedTypedText = NSAttributedString(string: "")

    var body: some View {
        ZStack(alignment: .topLeading) {

            // This text view sets the proper height for the speech bubble.
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .visibility(.invisible)

            if #available(macOS 12, *) {

                Text(AttributedString(attributedTypedText))
                    .frame(maxWidth: .infinity, alignment: .leading)

            } else {

                Text(typedText)
                    .frame(maxWidth: .infinity, alignment: .leading)

            }

        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .lineLimit(nil)
        .multilineTextAlignment(.leading)
        .font(.daxSpeech)
        .lineSpacing(2.5)
        .foregroundColor(Color(.onboardingDaxSpeechText))
        .frame(width: speechWidth)
        .background(SpeechBubble())
        .onReceive(timer, perform: { _ in
            if model.typingDisabled {
                typedText = text
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { _ in onTypingFinished?() })
                self.timer.upstream.connect().cancel()
                return
            } else if model.skipTypingRequested {
                typedText = text
            }

            if typedText == text {
                onTypingFinished?()
                self.timer.upstream.connect().cancel()
                return
            }

            let chars = Array(text)
            typingIndex = min(typingIndex + 1, chars.count)
            let typedChars = chars[0 ..< typingIndex]

            typedText = String(typedChars)

        })
    }

}

fileprivate struct SpeechBubble: View {

    let radius: CGFloat = 8
    let tailSize: CGFloat = 12
    let tailPosition: CGFloat = 32
    let tailHeight: CGFloat = 22

    var body: some View {
        ZStack {
            GeometryReader { g in
                let rect = CGRect(x: 0, y: 0, width: g.size.width, height: g.size.height)

                Path { path in

                    path.move(to: CGPoint(x: rect.minX, y: rect.maxY - radius))

                    path.addLine(to: CGPoint(x: rect.minX, y: tailPosition + tailHeight / 2))
                    path.addLine(to: CGPoint(x: rect.minX - tailSize, y: tailPosition))
                    path.addLine(to: CGPoint(x: rect.minX, y: tailPosition - tailHeight / 2))

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
                .fill(Color(.interfaceBackground))
                .shadow(color: Color(.onboardingDaxSpeechShadow), radius: 2, x: 0, y: 0)
            }

        }
    }
}

}

fileprivate extension Font {
    static var daxSpeech: Font = .system(size: 15, weight: .light, design: .default)
}
