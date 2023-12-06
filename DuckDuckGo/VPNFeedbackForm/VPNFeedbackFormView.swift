//
//  VPNFeedbackFormView.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

#if NETWORK_PROTECTION

struct VPNFeedbackFormView: View {

    @EnvironmentObject var viewModel: VPNFeedbackFormViewModel

    var body: some View {
        VStack(spacing: 0) {
            Group {
                Text("Report an Issue")
                    .font(.title2)
            }
            .frame(height: 70)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.1))

            Divider()

            switch viewModel.viewState {
            case .feedbackPending, .feedbackSending, .feedbackSendingFailed:
                VPNFeedbackFormBodyView()
                .padding([.top, .leading, .trailing], 20)

                if viewModel.viewState == .feedbackSendingFailed {
                    Text("We couldn't send your feedback right now, please try again.")
                        .foregroundColor(.red)
                        .padding(.top, 15)
                }
            case .feedbackSent:
                VPNFeedbackFormSentView()
                    .padding([.top, .leading, .trailing], 20)
            }

            Spacer(minLength: 0)

            VPNFeedbackFormButtons()
                .padding(20)
        }
    }

}

private struct VPNFeedbackFormBodyView: View {

    @EnvironmentObject var viewModel: VPNFeedbackFormViewModel

    var body: some View {
        Group {
            Picker(selection: $viewModel.selectedFeedbackCategory, content: {
                ForEach(VPNFeedbackCategory.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }, label: {})
            .controlSize(.large)
            .padding(.bottom, 0)

            switch viewModel.selectedFeedbackCategory {
            case .landingPage:
                Spacer()
                    .frame(height: 50)
            case .unableToInstall,
                    .failsToConnect,
                    .tooSlow,
                    .issueWithAppOrWebsite,
                    .cantConnectToLocalDevice,
                    .appCrashesOrFreezes,
                    .featureRequest,
                    .somethingElse:
                VPNFeedbackFormIssueDescriptionForm()
            }
        }
    }

}

private struct VPNFeedbackFormIssueDescriptionForm: View {

    @EnvironmentObject var viewModel: VPNFeedbackFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Please describe what's happening, what you expected to happen, and the steps that led to the issue:")
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            if #available(macOS 12, *) {
                FocusableTextEditor(text: $viewModel.feedbackFormText)
            } else {
                // TODO: Add macOS 11 support. Using the approach from Autofill is causing obscure compilation errors here.
            }

            Text("In addition to the details entered into this form, your app issue report will contain:")
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.secondary)

            VStack(alignment: .leading) {
                Text("• Whether specific DuckDuckGo features are enabled")
                    .foregroundColor(.secondary)
                Text("• Aggregate DuckDuckGo app diagnostics")
                    .foregroundColor(.secondary)
            }

            Text("By clicking \"Submit\" I agree that DuckDuckGo may use the information in this report for purposes of improving the app's features.")
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.secondary)
        }
    }

}

private struct VPNFeedbackFormSentView: View {

    var body: some View {
        VStack(spacing: 0) {
            Image("JoinWaitlistHeader")

            Text("Thank you!")
                .font(.system(size: 18, weight: .medium))
                .padding(.top, 30)

            Text("Your feedback will help us improve the\nDuckDuckGo app.")
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
    }

}

private struct VPNFeedbackFormButtons: View {

    @EnvironmentObject var viewModel: VPNFeedbackFormViewModel

    var body: some View {
        HStack {
            if viewModel.viewState == .feedbackSent {
                Button(action: {
                    viewModel.process(action: .cancel)
                }, label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                })
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            } else {
                Button(action: {
                    viewModel.process(action: .cancel)
                }, label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                })
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Button(action: {
                    viewModel.process(action: .submit)
                }, label: {
                    Text(viewModel.viewState == .feedbackSending ? "Submitting..." : "Submit")
                        .frame(maxWidth: .infinity)
                })
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(!viewModel.submitButtonEnabled)
            }
        }
    }

}

#endif
