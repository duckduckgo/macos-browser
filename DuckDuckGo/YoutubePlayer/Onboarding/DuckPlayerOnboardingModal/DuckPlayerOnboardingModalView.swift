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
    private enum Constants {
        static let outerContainerWidth: CGFloat = 504
        static let smallContainerHeight: CGFloat = 166
        static let bigContainerHeight: CGFloat = 350
        static let containerCornerRadius: CGFloat = 12
        static let darkModeBorderColor: Color = .white.opacity(0.2)
        static let whiteModeBorderColor: Color = .black.opacity(0.1)
    }

    @ObservedObject var viewModel: DuckPlayerOnboardingViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        currentView
            .padding()
            .frame(width: Constants.outerContainerWidth, height: containerHeight)
            .padding(.horizontal)
            .background(Color("DialogPanelBackground"))
            .cornerRadius(Constants.containerCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.containerCornerRadius)
                    .stroke(colorScheme == .dark ? Constants.darkModeBorderColor : Constants.whiteModeBorderColor, lineWidth: 1)
            )
    }

    private var containerHeight: CGFloat {
        switch viewModel.currentView {
        case .confirmation:
            return Constants.smallContainerHeight

        case .onboardingOptions:
            return Constants.bigContainerHeight
        }
    }

    @ViewBuilder
    var currentView: some View {
        switch viewModel.currentView {
        case .confirmation:
            DuckPlayerOnboardingConfirmationView {
                viewModel.handleGotItCTA()
            }

        case .onboardingOptions:
            DuckPlayerOnboardingChoiceView(turnOnButtonPressed: {
                viewModel.currentView = .confirmation
                viewModel.handleTurnOnCTA()
            }, notNowPressed: viewModel.handleNotNowCTA)
        }
    }
}

private enum Constants {
    enum FontSize {
        static let title: CGFloat = 17
        static let body: CGFloat = 13
    }

    enum Layout {
        static let modalOuterVerticalSpacing: CGFloat = 20
        static let modalInnerVerticalSpacing: CGFloat = 8
    }
}

private struct DuckPlayerOnboardingChoiceView: View {
    let turnOnButtonPressed: () -> Void
    let notNowPressed: () -> Void

    var body: some View {
        VStack(spacing: Constants.Layout.modalOuterVerticalSpacing) {
            DaxSpeechBubble {
                VStack (alignment: .leading, spacing: Constants.Layout.modalInnerVerticalSpacing) {
                    VStack (alignment: .leading, spacing: 0) {
                        Text(UserText.duckPlayerOnboardingChoiceModalTitleTop)
                        Text(UserText.duckPlayerOnboardingChoiceModalTitleBottom)
                    }
                    .font(.system(size: Constants.FontSize.title).weight(.bold))
                    .padding(.horizontal)

                    Text(UserText.duckPlayerOnboardingChoiceModalMessage)
                        .font(.system(size: Constants.FontSize.body))
                        .multilineText()
                        .lineSpacing(4)
                        .padding(.horizontal)

                    HStack {
                        Spacer()
                        Image("DuckPlayerOnboardingModal")
                        Spacer()
                    }
                }.frame(maxWidth: .infinity)
                    .padding()

            }

            HStack {
                Button {
                    notNowPressed()
                } label: {
                    Text(UserText.duckPlayerOnboardingChoiceModalCTADeny)
                }
                .buttonStyle(SecondaryCTAStyle())

                Spacer()
                Button {
                    turnOnButtonPressed()
                } label: {
                    Text(UserText.duckPlayerOnboardingChoiceModalCTAConfirm)
                }
                .buttonStyle(PrimaryCTAStyle())

            }
        }
    }
}

private struct DuckPlayerOnboardingConfirmationView: View {
    let voidButtonPressed: () -> Void
    var body: some View {
        VStack(spacing: Constants.Layout.modalOuterVerticalSpacing) {
            DaxSpeechBubble {
                VStack(alignment: .leading, spacing: Constants.Layout.modalInnerVerticalSpacing) {
                    Text(UserText.duckPlayerOnboardingConfirmationModalTitle)
                        .foregroundColor(.systemGray90)
                        .font(.system(size: Constants.FontSize.title).weight(.bold))
                        .padding(.horizontal)

                    Text(UserText.duckPlayerOnboardingConfirmationModalMessage)
                        .foregroundColor(.systemGray90)
                        .font(.system(size: Constants.FontSize.body))
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }

            Button {
                voidButtonPressed()
            } label: {
                Text(UserText.duckPlayerOnboardingConfirmationModalCTAConfirm)
            }
            .buttonStyle(PrimaryCTAStyle())
        }
    }
}

private struct DaxSpeechBubble<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                Image("DuckPlayerOnboardingModalDax")
                    .padding(.leading, -10)
                    .padding(.top, 8)

                ZStack {
                    SpeechBubble()
                    content
                }
            }
        }
    }
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

private enum CTAConstants {
    static let CTACornerRadius: CGFloat = 8
}

private struct PrimaryCTAStyle: ButtonStyle {

    func makeBody(configuration: Self.Configuration) -> some View {

        let color = configuration.isPressed ? Color("DuckPlayerOnboardingPrimaryButtonPressed") : Color("DuckPlayerOnboardingPrimaryButton")

        configuration.label
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .truncationMode(.tail)
            .background(RoundedRectangle(cornerRadius: CTAConstants.CTACornerRadius, style: .continuous).fill(color))
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
                RoundedRectangle(cornerRadius: CTAConstants.CTACornerRadius, style: .continuous)
                    .fill(color)
                    .shadow(color: .black.opacity(0.1), radius: 0.1, x: 0, y: 1)
                    .shadow(color: .primary.opacity(outterShadowOpacity), radius: 0.1, x: 0, y: -0.6))

            .overlay(
                RoundedRectangle(cornerRadius: CTAConstants.CTACornerRadius)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1))
    }
}

#Preview {
    VStack {
        DuckPlayerOnboardingChoiceView(turnOnButtonPressed: {

        }, notNowPressed: {

        })

        Divider()
            .padding()

        DuckPlayerOnboardingConfirmationView(voidButtonPressed: {

        })
    }
    .frame(width: 504)
    .fixedSize()
    .padding()
}
