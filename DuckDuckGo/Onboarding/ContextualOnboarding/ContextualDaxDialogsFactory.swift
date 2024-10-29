//
//  ContextualDaxDialogsFactory.swift
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

import Foundation
import SwiftUI
import Onboarding

protocol ContextualDaxDialogsFactory {
    func makeView(for type: ContextualDialogType, delegate: OnboardingNavigationDelegate, onDismiss: @escaping () -> Void, onGotItPressed: @escaping () -> Void, onFireButtonPressed: @escaping () -> Void) -> AnyView
}

struct DefaultContextualDaxDialogViewFactory: ContextualDaxDialogsFactory {
    private let onboardingPixelReporter: OnboardingPixelReporting

    init(onboardingPixelReporter: OnboardingPixelReporting = OnboardingPixelReporter()) {
        self.onboardingPixelReporter = onboardingPixelReporter
    }

    func makeView(for type: ContextualDialogType, delegate: any OnboardingNavigationDelegate, onDismiss: @escaping () -> Void, onGotItPressed: @escaping () -> Void, onFireButtonPressed: @escaping () -> Void) -> AnyView {
        let dialogView: AnyView
        switch type {
        case .tryASearch:
            dialogView = AnyView(tryASearchDialog(delegate: delegate))
        case .searchDone(shouldFollowUp: let shouldFollowUp):
            dialogView = AnyView(searchDoneDialog(shouldFollowUp: shouldFollowUp, delegate: delegate, onDismiss: onDismiss, onGotItPressed: onGotItPressed))
        case .tryASite:
            dialogView = AnyView(tryASiteDialog(delegate: delegate))
        case .trackers(message: let message, shouldFollowUp: let shouldFollowUp):
            dialogView = AnyView(trackersDialog(message: message, shouldFollowUp: shouldFollowUp, onDismiss: onDismiss, onGotItPressed: onGotItPressed, onFireButtonPressed: onFireButtonPressed))
        case .tryFireButton:
            dialogView = AnyView(tryFireButtonDialog(onDismiss: onDismiss, onGotItPressed: onGotItPressed, onFireButtonPressed: onFireButtonPressed))
        case .highFive:
            dialogView = AnyView(highFiveDialog(onDismiss: onDismiss, onGotItPressed: onGotItPressed))
            onboardingPixelReporter.trackLastDialogShown()
        }
        let adjustedView = {
            HStack {
                Spacer()
                dialogView
                    .frame(maxWidth: 640.0)
                Spacer()
            }
            .padding()
        }
        let viewWithBackground = adjustedView().background(OnboardingGradient())

        return AnyView(viewWithBackground)
    }

    private func tryASearchDialog(delegate: OnboardingNavigationDelegate) -> some View {
        let suggestedSearchedProvider = OnboardingSuggestedSearchesProvider()
        let viewModel = OnboardingSearchSuggestionsViewModel(suggestedSearchesProvider: suggestedSearchedProvider, delegate: delegate, pixelReporter: onboardingPixelReporter)

        return OnboardingTrySearchDialog(viewModel: viewModel)
    }

    private func searchDoneDialog(shouldFollowUp: Bool, delegate: OnboardingNavigationDelegate, onDismiss: @escaping () -> Void, onGotItPressed: @escaping () -> Void) -> some View {
        let suggestedSitesProvider = OnboardingSuggestedSitesProvider(surpriseItemTitle: OnboardingSuggestedSitesProvider.surpriseItemTitle)
        let viewModel = OnboardingSiteSuggestionsViewModel(title: "", suggestedSitesProvider: suggestedSitesProvider, delegate: delegate, pixelReporter: onboardingPixelReporter)
        let gotIt = shouldFollowUp ? onGotItPressed : onDismiss

        return OnboardingFirstSearchDoneDialog(shouldFollowUp: shouldFollowUp, viewModel: viewModel, gotItAction: gotIt)
    }

    private func tryASiteDialog(delegate: OnboardingNavigationDelegate) -> some View {
        let suggestedSitesProvider = OnboardingSuggestedSitesProvider(surpriseItemTitle: OnboardingSuggestedSitesProvider.surpriseItemTitle)
        let viewModel = OnboardingSiteSuggestionsViewModel(title: "", suggestedSitesProvider: suggestedSitesProvider, delegate: delegate, pixelReporter: onboardingPixelReporter)

        return OnboardingTryVisitingASiteDialog(viewModel: viewModel)
    }

    private func trackersDialog(message: NSAttributedString, shouldFollowUp: Bool, onDismiss: @escaping () -> Void, onGotItPressed: @escaping () -> Void, onFireButtonPressed: @escaping () -> Void) -> some View {
        let gotIt = shouldFollowUp ? onGotItPressed : onDismiss
        let viewModel = OnboardingFireButtonDialogViewModel(onboardingPixelReporter: onboardingPixelReporter, onDismiss: onDismiss, onGotItPressed: onGotItPressed, onFireButtonPressed: onFireButtonPressed)
        return OnboardingTrackersDoneDialog(shouldFollowUp: true, message: message, blockedTrackersCTAAction: gotIt, viewModel: viewModel)
    }

    private func tryFireButtonDialog(onDismiss: @escaping () -> Void, onGotItPressed: @escaping () -> Void, onFireButtonPressed: @escaping () -> Void) -> some View {
        let viewModel = OnboardingFireButtonDialogViewModel(onboardingPixelReporter: onboardingPixelReporter, onDismiss: onDismiss, onGotItPressed: onGotItPressed, onFireButtonPressed: onFireButtonPressed)
        return OnboardingFireDialog(viewModel: viewModel)
    }

    private func highFiveDialog(onDismiss: @escaping () -> Void, onGotItPressed: @escaping () -> Void) -> some View {
        let action = {
            onDismiss()
            onGotItPressed()
        }
        return OnboardingFinalDialog(highFiveAction: action)
    }
}

extension OnboardingSuggestedSitesProvider {
    static let surpriseItemTitle = UserText.ContextualOnboarding.tryASearchOptionSurpriseMeTitle
}
