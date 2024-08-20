//
//  DuckPlayerOnboardingModalView.swift
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

struct DuckPlayerOnboardingModalView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            HStack (alignment: .top) {
                Image("DuckPlayerOnboardingModalDax")
                    .padding(.top, 8)
                    .padding(.leading, -10)

                    VStack (alignment: .leading) {
                        Text("Drowning in ads on YouTube?")
                            .font(.title)
                            .padding(.horizontal)

                        Text("Duck Player lets you watch without targeted ads and comes free to use in DuckDuckGo.")
                            .multilineText()
                            .padding(.horizontal)

                        HStack {
                            Spacer()
                            Image("DuckPlayerOnboardingModal")
                            Spacer()
                        }
                    }.background(
                        SpeechBubble()
                            .frame(width: 432, height: 198)
                    )
                    .padding(24)
                }

            HStack {
                Button {

                } label: {
                    Text("Not Now")
                }
                .buttonStyle(SecondaryCTAStyle())

                Spacer()
                Button {

                } label: {
                    Text("Turn on Duck Player")
                }
                .buttonStyle(PrimaryCTAStyle())
            }
        }
        .frame(width: Consts.Layout.outerContainerWidth, height: Consts.Layout.outerContainerHeight)
        .padding(.horizontal)
        .background(Color("DialogPanelBackground"))
        .cornerRadius(Consts.Layout.containerCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Consts.Layout.containerCornerRadius)
                .stroke(colorScheme == .dark ? Consts.Colors.darkModeBorderColor : Consts.Colors.whiteModeBorderColor, lineWidth: 1)
        )

    }
}

#Preview {
    DuckPlayerOnboardingModalView()
}

private struct SpeechBubble: View {

    let radius: CGFloat = 20
    let tailSize: CGFloat = 12
    let tailPosition: CGFloat = 38
    let tailHeight: CGFloat = 28

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

private struct PrimaryCTAStyle: ButtonStyle {

    func makeBody(configuration: Self.Configuration) -> some View {

        let color = configuration.isPressed ? Color("DuckPlayerOnboardingPrimaryButtonPressed") : Color("DuckPlayerOnboardingPrimaryButton")

        configuration.label
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .truncationMode(.tail)
            .background(RoundedRectangle(cornerRadius: Consts.Layout.CTACornerRadius, style: .continuous).fill(color))
            .foregroundColor(.white)
            .font(.system(size: 13, weight: .light, design: .default))
    }
}

private struct SecondaryCTAStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Self.Configuration) -> some View {

        let color = configuration.isPressed ? Color("DuckPlayerOnboardingSecondaryButtonPressed") : Color("DuckPlayerOnboardingSecondaryButton")

        let outterShadowOpacity = colorScheme == .dark ? 0.8 : 0.0

        configuration.label
            .font(.system(size: 13, weight: .light, design: .default))
            .foregroundColor(.primary)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Consts.Layout.CTACornerRadius, style: .continuous)
                .fill(color)
                .shadow(color: .black.opacity(0.1), radius: 0.1, x: 0, y: 1)
                .shadow(color: .primary.opacity(outterShadowOpacity), radius: 0.1, x: 0, y: -0.6))

            .overlay(
                RoundedRectangle(cornerRadius: Consts.Layout.CTACornerRadius)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1))
    }
}

private enum Consts {
    struct Layout {
        static let outerContainerWidth: CGFloat = 504
        static let outerContainerHeight: CGFloat = 286
        static let daxContainerWidth: CGFloat = 84
        static let containerCornerRadius: CGFloat = 12
        static let CTACornerRadius: CGFloat = 8
        static let containerPadding: CGFloat = 20
    }

    struct Colors {
        static let darkModeBorderColor: Color = .white.opacity(0.2)
        static let whiteModeBorderColor: Color = .black.opacity(0.1)
        static let daxShadow: Color = .black.opacity(0.16)
    }
    struct Font {
        static let size: CGFloat = 15
    }
}
