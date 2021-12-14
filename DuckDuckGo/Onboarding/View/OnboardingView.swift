//
//  OnboardingView.swift
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

let buttonColor = Color(red: 0.224, green: 0.412, blue: 0.937)

// https://swiftuirecipes.com/blog/how-to-hide-a-swiftui-view-visible-invisible-gone
enum ViewVisibility: CaseIterable {
  case visible, // view is fully visible
       invisible, // view is hidden but takes up space
       gone // view is fully removed from the view hierarchy
}

// https://swiftuirecipes.com/blog/how-to-hide-a-swiftui-view-visible-invisible-gone
extension View {
  @ViewBuilder func visibility(_ visibility: ViewVisibility) -> some View {
    if visibility != .gone {
      if visibility == .visible {
        self
      } else {
        hidden()
      }
    }
  }
}

struct SpeechBubble: View {

    let radius: CGFloat = 8
    let speechOffset: CGFloat = 40
    let tailSize: CGFloat = 8

    var body: some View {
        ZStack {
            GeometryReader { g in

                let width = g.size.width
                let height = g.size.height

                let rect = CGRect(x: 10, y: 0, width: width - 10, height: height)

                Path { path in

                    path.move(to: CGPoint(x: rect.minX, y: rect.maxY - radius))

                    path.addLine(to: CGPoint(x: rect.minX, y: 40))
                    path.addLine(to: CGPoint(x: rect.minX - 10, y: 30))
                    path.addLine(to: CGPoint(x: rect.minX, y: 20))

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

extension AnyTransition {

    static var moveBottom: AnyTransition {
        .move(edge: .bottom)
    }

    static var moveBottomFadeIn: AnyTransition {
        .move(edge: .bottom)
        .combined(with: .opacity)
    }

    static var moveLeadingTop: AnyTransition {
        .move(edge: .leading).combined(with: .move(edge: .top))
    }

    static var daxWelcome: AnyTransition {
        .asymmetric(insertion: .moveBottomFadeIn,
                    removal: .moveLeadingTop)
    }

}

private struct ActionButtonStyle: ButtonStyle {

    let skip: Bool
    let bgColor: Color = buttonColor

    func makeBody(configuration: Self.Configuration) -> some View {

        let fillColor = skip ? .black.opacity(0.06) : bgColor

        configuration.label
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .truncationMode(.tail)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(fillColor))
            .foregroundColor(skip ? .black : .white)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .font(.system(size: 13, weight: .bold, design: .default))

    }
}

struct SpeechTextModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .light))
            .lineSpacing(5)
            .padding(.horizontal)
    }

}

struct DaxSpeech: View {

    let text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(text)
                .kerning(-0.23)
                .modifier(SpeechTextModifier())
        }
        .frame(width: 314)
        .padding()
        .background(SpeechBubble())
    }

}

struct ActionSpeech: View {

    let text: String
    let actionName: String
    let action: () -> Void
    let skip: () -> Void

    var body: some View {
        VStack {
            DaxSpeech(text: text)

            HStack {

                Button("Not Now") {
                    skip()
                }
                .buttonStyle(ActionButtonStyle(skip: true))

                Button(actionName) {
                    action()
                }
                .buttonStyle(ActionButtonStyle(skip: false))

            }
            .padding(.leading, 10)
            .frame(width: 290)

        }
    }

}

struct CallToAction: View {

    let text: String
    let cta: String

    let onNext: () -> Void

    var body: some View {
        VStack {
            DaxSpeech(text: text)

            Button(cta) {
                onNext()
            }
            .frame(width: 290)
            .padding(.leading, 10)
            .buttonStyle(ActionButtonStyle(skip: false))

        }
    }

}

struct DaxConversation: View {

    enum OnboardingPhase {

        case start
        case welcome
        case importData
        case setDefault
        case startBrowsing

    }

    weak var delegate: OnboardingDelegate?

    let image = Image("OnboardingDax")

    @State var makeSpace = false
    @State var showLogo = false
    @State var showTitle = true
    @State var showSpeech = false
    @State var phase: OnboardingPhase = .start

    func moveToPhase(_ phase: OnboardingPhase) {
        withAnimation {
            self.phase = phase
        }
    }

    var body: some View {

        VStack(alignment: showSpeech ? .leading : .center) {

            Text(UserText.onboardingWelcomeTitle)
                .kerning(-1.26)
                .font(.system(size: 42, weight: .bold, design: .default))
                .foregroundColor(.black)
                .visibility(showTitle ? .visible : .gone)

            Color.clear.frame(width: 60, height: 60)
                .visibility(makeSpace ? .visible : .gone)

            HStack(alignment: .top) {

                image
                    .resizable()
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 3)
                    .transition(.daxWelcome)

                CallToAction(text: UserText.onboardingWelcomeText, cta: UserText.onboardingStartButton) {
                    moveToPhase(.importData)
                }
                .visibility(showSpeech && phase == .welcome ? .visible : .gone)

                ActionSpeech(text: UserText.onboardingImportDataText, actionName: UserText.onboardingImportDataButton) {
                    delegate?.onboardingDidRequestImportData {
                        moveToPhase(.setDefault)
                    }
                } skip: {
                    moveToPhase(.setDefault)
                }
                .visibility(showSpeech && phase == .importData ? .visible : .gone)

                ActionSpeech(text: UserText.onboardingSetDefaultText, actionName: UserText.onboardingSetDefaultButton) {
                    delegate?.onboardingDidRequestSetDefault {
                        moveToPhase(.startBrowsing)
                    }
                } skip: {
                    moveToPhase(.startBrowsing)
                }
                .visibility(showSpeech && phase == .setDefault ? .visible : .gone)

                CallToAction(text: UserText.onboardingStartBrowsingText, cta: UserText.onboardingStartBrowsingButton) {
                    delegate?.onboardingDidRequestStartBrowsing()
                }
                .onAppear {
                    delegate?.onboardingHasFinished()
                }
                .visibility(showSpeech && phase == .startBrowsing ? .visible : .gone)

                Spacer()
                    .visibility(showSpeech ? .visible : .gone)

            }.visibility(showLogo ? .visible : .gone)

            Spacer().visibility(showSpeech ? .visible : .gone)

        }
        .padding()
        .onAppear {

            withAnimation(.easeIn(duration: 0.5).delay(1.5)) {
                makeSpace = true
            }

            withAnimation(.easeIn(duration: 0.5).delay(2.0)) {
                showLogo = true
                makeSpace = false
            }

            withAnimation(.easeIn.delay(3.0)) {
                showTitle = false
                showSpeech = true
            }

            withAnimation(.easeIn.delay(3.5)) {
                phase = .welcome
            }

        }

    }

}

struct OnboardingView: View {

    // swiftlint:disable weak_delegate
    let delegate: OnboardingDelegate
    // swiftlint:enable weak_delegate

    let image = Image("OnboardingBackground")

    @State var showDax = false
    @State var showImage = false

    var body: some View {
        ZStack {
            if showImage {
                image
                    .resizable()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.animation(.easeIn(duration: 1).delay(0.5)))
            }

            if showDax {
                DaxConversation(delegate: delegate)
            }

        }
        // .frame(width: 800, height: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onAppear {
            withAnimation {
                showImage = true
                showDax = true
            }
        }
    }

}
