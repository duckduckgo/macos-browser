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
    static let titleFont = Font.system(size: 20, weight: .bold, design: .rounded)
    static let messageFont = Font.system(size: Self.messageFontSize, weight: .regular, design: .rounded)
    static let messageFontSize = 16.0
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
    private let attributedMessage: NSAttributedString = {
        let firstString = UserText.ContextualOnboarding.onboardingTryFireButtonMessage
        let boldString = "Fire Button"
        let attributedString = NSMutableAttributedString(string: firstString)
        let boldFontAttribute: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: OnboardingDialogsContants.messageFontSize, weight: .bold)
        ]
        if let boldRange = firstString.range(of: boldString) {
            let nsBoldRange = NSRange(boldRange, in: firstString)
            attributedString.addAttributes(boldFontAttribute, range: nsBoldRange)
        }

        return attributedString
    }()

    let viewModel: OnboardingFireButtonDialogViewModel

    var body: some View {
        ContextualDaxDialogContent(
            orientation: .horizontalStack(alignment: .center),
            message: attributedMessage,
            messageFont: OnboardingDialogsContants.messageFont,
            customActionView: AnyView(actionView))
    }

    @ViewBuilder
    private var actionView: some View {
        VStack {
            OnboardingPrimaryCTAButton(title: "Try it", action: viewModel.tryFireButton)
            OnboardingSecondaryCTAButton(title: UserText.skip, action: viewModel.skip)
        }
    }

}

struct OnboardingFireDialog: View {
    let viewModel: OnboardingFireButtonDialogViewModel

    var body: some View {
        DaxDialogView(logoPosition: .left) {
            OnboardingFireButtonDialogContent(viewModel: viewModel)
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

struct OnboardingFinalDialog: View {
    let title = UserText.ContextualOnboarding.onboardingFinalScreenTitle
    let message = NSAttributedString(string: UserText.ContextualOnboarding.onboardingFinalScreenMessage)
    let cta = UserText.ContextualOnboarding.onboardingFinalScreenButton

    let highFiveAction: () -> Void

    var body: some View {
        DaxDialogView(logoPosition: .left) {
            ContextualDaxDialogContent(orientation: .horizontalStack(alignment: .center),
                                       title: title,
                                       titleFont: OnboardingDialogsContants.titleFont,
                                       message: message,
                                       messageFont: OnboardingDialogsContants.messageFont,
                                       customActionView: AnyView(OnboardingPrimaryCTAButton(title: cta, action: highFiveAction)))
        }
    }
}

struct OnboardingPrimaryCTAButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.vertical, 3)
                .padding(.horizontal, 24)
        }
        .buttonStyle(DefaultActionButtonStyle(enabled: true))
        .shadow(radius: 1, x: -0.6, y: +0.6)
    }

}

struct OnboardingSecondaryCTAButton: View {
    @Environment(\.colorScheme) var colorScheme

    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
            .padding(.vertical, 3)
            .padding(.horizontal, 26)
        }
        .buttonStyle(DismissActionButtonStyle())
    }

}

// MARK: - Preview

#Preview("Try Search") {
    OnboardingTrySearchDialog(viewModel: OnboardingSearchSuggestionsViewModel(suggestedSearchesProvider: OnboardingSuggestedSearchesProvider(), pixelReporter: OnboardingPixelReporter()))
        .padding()
}

final class OnboardingPixelReporter: OnboardingSearchSuggestionsPixelReporting, OnboardingSiteSuggestionsPixelReporting {
    func trackSiteSuggetionOptionTapped() {
    }
    func trackSearchSuggetionOptionTapped() {
    }
}

#Preview("Try Site") {
    OnboardingTryVisitingSiteDialog(viewModel: OnboardingSiteSuggestionsViewModel(title: "", suggestedSitesProvider: OnboardingSuggestedSitesProvider(surpriseItemTitle: UserText.ContextualOnboarding.tryASearchOptionSurpriseMeTitle), pixelReporter: OnboardingPixelReporter()))
        .padding()
}

#Preview("First Search Dialog") {
    OnboardingFirstSearchDoneDialog(shouldFollowUp: true, viewModel: OnboardingSiteSuggestionsViewModel(title: UserText.ContextualOnboarding.onboardingTryASiteTitle, suggestedSitesProvider: OnboardingSuggestedSitesProvider(surpriseItemTitle: UserText.ContextualOnboarding.tryASearchOptionSurpriseMeTitle), pixelReporter: OnboardingPixelReporter()), gotItAction: {})
        .padding()
}

#Preview("Try Fire Button") {
    DaxDialogView(logoPosition: .left) {
        OnboardingFireButtonDialogContent(viewModel: OnboardingFireButtonDialogViewModel(onDismiss: {}))
    }
    .padding()
}

#Preview("Trackers Dialog") {
    let message: NSAttributedString = {
        let firstString = UserText.ContextualOnboarding.onboardingTryFireButtonMessage
        return NSMutableAttributedString(string: firstString)
    }()
    return OnboardingTrackersDoneDialog(shouldFollowUp: true, message: message, blockedTrackersCTAAction: {}, viewModel: OnboardingFireButtonDialogViewModel(onDismiss: {}))
        .padding()
}
