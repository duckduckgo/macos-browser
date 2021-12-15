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

extension Onboarding {

struct DaxSpeech: View {

    let text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(text)
                .kerning(-0.23)
                .font(.system(size: 15, weight: .light))
                .lineSpacing(5)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .frame(width: 328)
        .background(SpeechBubble())
    }

}

fileprivate struct SpeechBubble: View {

    let radius: CGFloat = 8
    let speechOffset: CGFloat = 40
    let tailSize: CGFloat = 8
    let tailPosition: CGFloat = 32

    var body: some View {
        ZStack {
            GeometryReader { g in

                let width = g.size.width
                let height = g.size.height

                let rect = CGRect(x: 0, y: 0, width: width, height: height)

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
