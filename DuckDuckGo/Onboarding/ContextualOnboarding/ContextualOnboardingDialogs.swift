//
//  ContextualOnboardingDialogs.swift
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
import Onboarding
import SwiftUIExtensions

struct OnboardingDialogsContants {
    static let titleFont = Font.system(size: Self.titleFontSize, weight: .bold, design: .rounded)
    static let messageFont = Font.system(size: Self.messageFontSize, weight: .regular, design: .rounded)
    static let titleFontNotBold = Font.system(size: Self.titleFontSize, weight: .regular, design: .rounded)
    static let messageFontSize = 16.0
    static let titleFontSize = 20.0
}

struct OnboardingTrySearchDialog: View {
    let title = UserText.ContextualOnboarding.onboardingTryASearchTitle
    let message = NSAttributedString(string: UserText.ContextualOnboarding.onboardingTryASearchMessage)
    let viewModel: OnboardingSearchSuggestionsViewModel

    var body: some View {
        DaxDialogView(logoPosition: .left) {
            ContextualDaxDialogContent(
                orientation: .horizontalStack(alignment: .top),
                title: title,
                titleFont: OnboardingDialogsContants.titleFont,
                message: message,
                messageFont: OnboardingDialogsContants.messageFont,
                list: viewModel.itemsList,
                listAction: viewModel.listItemPressed
            )
        }
        .padding()
    }

}

struct OnboardingTryVisitingSiteDialog: View {
    let viewModel: OnboardingSiteSuggestionsViewModel

    var body: some View {
        DaxDialogView(logoPosition: .left) {
            OnboardingTryVisitingSiteDialogContent(viewModel: viewModel)
        }
        .padding()

    }
}

struct OnboardingTryVisitingSiteDialogContent: View {
    let title = UserText.ContextualOnboarding.onboardingTryASiteTitle
    let message = NSAttributedString(string: UserText.ContextualOnboarding.onboardingTryASiteMessage)

    let viewModel: OnboardingSiteSuggestionsViewModel

    var body: some View {
        ContextualDaxDialogContent(
            orientation: .horizontalStack(alignment: .top),
            title: title,
            titleFont: OnboardingDialogsContants.titleFont,
            message: message,
            messageFont: OnboardingDialogsContants.messageFont,
            list: viewModel.itemsList,
            listAction: viewModel.listItemPressed)
    }
}

struct OnboardingTryVisitingASiteDialog: View {
    let viewModel: OnboardingSiteSuggestionsViewModel

    var body: some View {
        DaxDialogView(logoPosition: .left) {
            OnboardingTryVisitingSiteDialogContent(viewModel: viewModel)
        }
    }
}

struct OnboardingFirstSearchDoneDialog: View {
    let title = UserText.ContextualOnboarding.onboardingFirstSearchDoneTitle
    let message = NSAttributedString(string: UserText.ContextualOnboarding.onboardingFirstSearchDoneMessage)
    let cta = UserText.ContextualOnboarding.onboardingGotItButton

    @State private var showNextScreen: Bool = false

    let shouldFollowUp: Bool
    let viewModel: OnboardingSiteSuggestionsViewModel
    let gotItAction: () -> Void

    var body: some View {
        DaxDialogView(logoPosition: .left) {
            VStack {
                if showNextScreen {
                    OnboardingTryVisitingSiteDialogContent(viewModel: viewModel)
                } else {
                    ContextualDaxDialogContent(
                        orientation: .horizontalStack(alignment: .center),
                        title: title,
                        titleFont: OnboardingDialogsContants.titleFont,
                        message: message,
                        messageFont: OnboardingDialogsContants.messageFont,
                        customActionView: AnyView(
                            OnboardingPrimaryCTAButton(title: cta) {
                                gotItAction()
                                withAnimation {
                                    if shouldFollowUp {
                                        showNextScreen = true
                                    }
                                }
                            }
                        )
                    )
                }
            }
        }
        .padding()

    }
}

struct OnboardingFireButtonDialogContent: View {
    static let firstString = String(format: UserText.ContextualOnboarding.onboardingTryFireButtonTitle, UserText.ContextualOnboarding.onboardingTryFireButtonMessage)
    private let attributedMessage = NSMutableAttributedString.attributedString(
        from: Self.firstString,
        defaultFontSize: OnboardingDialogsContants.titleFontSize,
        boldFontSize: OnboardingDialogsContants.titleFontSize,
        customPart: UserText.ContextualOnboarding.onboardingTryFireButtonMessage,
        customFontSize: OnboardingDialogsContants.messageFontSize
    )

    let viewModel: OnboardingFireButtonDialogViewModel
    @State private var showNextScreen: Bool = false

    var body: some View {
        if showNextScreen {
            OnboardingFinalDialogContent(highFiveAction: viewModel.highFive)
        } else {
            ContextualDaxDialogContent(
                orientation: .horizontalStack(alignment: .center),
                message: attributedMessage,
                messageFont: OnboardingDialogsContants.titleFontNotBold,
                customActionView: AnyView(actionView))
        }
    }

    @ViewBuilder
    private var actionView: some View {
        VStack {
            OnboardingPrimaryCTAButton(title: UserText.ContextualOnboarding.onboardingTryFireButtonButton, action: viewModel.tryFireButton)
            OnboardingSecondaryCTAButton(title: UserText.skip, action: {
                showNextScreen = true
                viewModel.skip()
            })
        }
    }

}

struct OnboardingFireDialog: View {
    let viewModel: OnboardingFireButtonDialogViewModel
    @State private var showNextScreen: Bool = false

    var body: some View {
        DaxDialogView(logoPosition: .left) {
            if showNextScreen {
                OnboardingFinalDialogContent(highFiveAction: viewModel.highFive)
            } else {
                OnboardingFireButtonDialogContent(viewModel: viewModel)
            }
        }
        .padding()
    }
}

struct OnboardingTrackersDoneDialog: View {
    let cta = UserText.ContextualOnboarding.onboardingGotItButton

    @State private var showNextScreen: Bool = false

    let shouldFollowUp: Bool
    let message: NSAttributedString
    let blockedTrackersCTAAction: () -> Void

    let viewModel: OnboardingFireButtonDialogViewModel

    var body: some View {
        DaxDialogView(logoPosition: .left) {
            VStack {
                if showNextScreen {
                    OnboardingFireButtonDialogContent(viewModel: viewModel)
                } else {
                    ContextualDaxDialogContent(
                        orientation: .horizontalStack(alignment: .center),
                        message: message,
                        messageFont: OnboardingDialogsContants.messageFont,
                        customActionView: AnyView(
                            OnboardingPrimaryCTAButton(title: cta) {
                                blockedTrackersCTAAction()
                                if shouldFollowUp {
                                    withAnimation {
                                        showNextScreen = true
                                    }
                                }
                            }
                        )
                    )
                }
            }
        }
        .padding()

    }
}

struct OnboardingFinalDialogContent: View {
    let title = UserText.ContextualOnboarding.onboardingFinalScreenTitle
    let message = NSAttributedString(string: UserText.ContextualOnboarding.onboardingFinalScreenMessage)
    let cta = UserText.ContextualOnboarding.onboardingFinalScreenButton
    let highFiveAction: () -> Void

    var body: some View {
        ContextualDaxDialogContent(orientation: .horizontalStack(alignment: .center),
                                   title: title,
                                   titleFont: OnboardingDialogsContants.titleFont,
                                   message: message,
                                   messageFont: OnboardingDialogsContants.messageFont,
                                   customActionView: AnyView(OnboardingPrimaryCTAButton(title: cta, action: highFiveAction)))
    }
}

struct OnboardingFinalDialog: View {
    let title = UserText.ContextualOnboarding.onboardingFinalScreenTitle
    let message = NSAttributedString(string: UserText.ContextualOnboarding.onboardingFinalScreenMessage)
    let cta = UserText.ContextualOnboarding.onboardingFinalScreenButton

    let highFiveAction: () -> Void

    var body: some View {
        DaxDialogView(logoPosition: .left) {
            OnboardingFinalDialogContent(highFiveAction: highFiveAction)
        }
    }
}

struct OnboardingPrimaryCTAButton: View {
    let title: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.vertical, 5)
                .padding(.horizontal, 24)
        }
        .buttonStyle(DefaultActionButtonStyle(enabled: true))
        .shadow(radius: 1, x: -0.6, y: +0.6)
    }

}

struct OnboardingSecondaryCTAButton: View {
    @Environment(\.colorScheme) var colorScheme
    private var strokeColor: Color {
        return (colorScheme == .dark) ? Color.white.opacity(0.12) : Color.black.opacity(0.09)
    }

    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
            .padding(.horizontal, 18)
        }
        .buttonStyle(OnboardingStyles.ListButtonStyle(maxWidth: nil))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .inset(by: 0.5)
                .stroke(strokeColor, lineWidth: 1)
        )
    }

}

// MARK: - Preview

#Preview("Try Search") {
    OnboardingTrySearchDialog(viewModel: OnboardingSearchSuggestionsViewModel(suggestedSearchesProvider: OnboardingSuggestedSearchesProvider(), pixelReporter: OnboardingPixelReporter(onboardingStateProvider: ContextualOnboardingStateMachine())))
        .padding()
}

#Preview("Try Site") {
    OnboardingTryVisitingSiteDialog(viewModel: OnboardingSiteSuggestionsViewModel(title: "", suggestedSitesProvider: OnboardingSuggestedSitesProvider(surpriseItemTitle: UserText.ContextualOnboarding.tryASearchOptionSurpriseMeTitle), pixelReporter: OnboardingPixelReporter(onboardingStateProvider: ContextualOnboardingStateMachine())))
        .padding()
}

#Preview("First Search Dialog") {
    OnboardingFirstSearchDoneDialog(shouldFollowUp: true, viewModel: OnboardingSiteSuggestionsViewModel(title: UserText.ContextualOnboarding.onboardingTryASiteTitle, suggestedSitesProvider: OnboardingSuggestedSitesProvider(surpriseItemTitle: UserText.ContextualOnboarding.tryASearchOptionSurpriseMeTitle), pixelReporter: OnboardingPixelReporter(onboardingStateProvider: ContextualOnboardingStateMachine())), gotItAction: {})
        .padding()
}

#Preview("Try Fire Button") {
    DaxDialogView(logoPosition: .left) {
        OnboardingFireButtonDialogContent(viewModel: OnboardingFireButtonDialogViewModel(onDismiss: {}, onGotItPressed: {}, onFireButtonPressed: {}))
    }
    .padding()
}

#Preview("Trackers Dialog") {
    let message: NSAttributedString = {
        let firstString = UserText.ContextualOnboarding.onboardingTryFireButtonMessage
        return NSMutableAttributedString(string: firstString)
    }()
    return OnboardingTrackersDoneDialog(shouldFollowUp: true, message: message, blockedTrackersCTAAction: {}, viewModel: OnboardingFireButtonDialogViewModel(onDismiss: {}, onGotItPressed: {}, onFireButtonPressed: {}))
        .padding()
}
