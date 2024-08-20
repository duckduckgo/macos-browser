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

                VStack (alignment: .leading) {
                    Text("Drowning in ads on YouTube?")
                        .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)

                    Text("Duck Player lets you watch without targeted ads and comes free to use in DuckDuckGo.")

                    HStack {
                        Spacer()
                        Image("DuckPlayerOnboardingModal")
                        Spacer()
                    }
                }

            }
            HStack {

                Button {

                } label: {
                    Text("Not Now")
                }
                .buttonStyle(SecondaryCTAStyle())

                Button {

                } label: {
                    Text("Turn on Duck Player")
                }
                .buttonStyle(PrimaryCTAStyle())


            }
        }
        .frame(width: 504, height: 296)
        .padding(Consts.Layout.containerPadding)
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

struct SpeechBalloon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Draw the balloon
        let balloonRect = CGRect(x: 20, y: 0, width: rect.width - 20, height: rect.height)
        path.addRoundedRect(in: balloonRect, cornerSize: CGSize(width: 28, height: 28))

        // Draw the curved tail
        let tailStart = CGPoint(x: 20, y: 40)
        let tailControl1 = CGPoint(x: 0, y: 0)
        let tailControl2 = CGPoint(x: 0, y: 40)
        let tailEnd = CGPoint(x: 20, y: 60)

        path.move(to: tailStart)
        path.addCurve(to: tailEnd, control1: tailControl1, control2: tailControl2)

        // Draw the inner curve of the tail
//        let innerTailControl1 = CGPoint(x: 10, y: 50)
//        let innerTailControl2 = CGPoint(x: 10, y: 10)
//        let innerTailEnd = CGPoint(x: 20, y: 20)
//
//        path.addCurve(to: innerTailEnd, control1: innerTailControl1, control2: innerTailControl2)

        return path
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
        static let outerContainerWidth: CGFloat = 490
        static let daxContainerWidth: CGFloat = 84
        static let innerContainerHeight: CGFloat = 190
        static let daxImageSize: CGFloat = 64
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
