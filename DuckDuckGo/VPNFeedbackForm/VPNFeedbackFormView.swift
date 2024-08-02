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

struct VPNFeedbackFormView: View {

    @EnvironmentObject var viewModel: VPNFeedbackFormViewModel

    var body: some View {
        VStack(spacing: 0) {
            Group {
                Text(UserText.vpnFeedbackFormTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
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
                    Text(UserText.vpnFeedbackFormSendingConfirmationError)
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
            Text(UserText.vpnFeedbackFormText1)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            textEditor()

            Text(UserText.vpnFeedbackFormText2)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.secondary)

            VStack(alignment: .leading) {
                Text(UserText.vpnFeedbackFormText3)
                    .foregroundColor(.secondary)
                Text(UserText.vpnFeedbackFormText4)
                    .foregroundColor(.secondary)
            }

            Text(UserText.vpnFeedbackFormText5)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    func textEditor() -> some View {
#if APPSTORE
        FocusableTextEditor(text: $viewModel.feedbackFormText, characterLimit: 1000)
#else
        if #available(macOS 12, *) {
            FocusableTextEditor(text: $viewModel.feedbackFormText, characterLimit: 1000)
        } else {
            TextEditor(text: $viewModel.feedbackFormText)
                .frame(height: 197.0)
                .font(.body)
                .foregroundColor(.primary)
                .onChange(of: viewModel.feedbackFormText) {
                    viewModel.feedbackFormText = String($0.prefix(1000))
                }
                .padding(EdgeInsets(top: 3.0, leading: 6.0, bottom: 5.0, trailing: 0.0))
                .clipShape(RoundedRectangle(cornerRadius: 8.0, style: .continuous))
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8.0)
                            .stroke(Color(.textEditorBorder), lineWidth: 0.4)
                        RoundedRectangle(cornerRadius: 8.0)
                            .fill(Color(.textEditorBackground))
                    }
                )
        }
#endif
    }

}

private struct VPNFeedbackFormSentView: View {

    var body: some View {
        VStack(spacing: 0) {
            Image(.vpnFeedbackSent)
                .padding(.top, 20)

            Text(UserText.vpnFeedbackFormSendingConfirmationTitle)
                .font(.system(size: 18, weight: .medium))
                .padding(.top, 30)

            Text(UserText.vpnFeedbackFormSendingConfirmationDescription)
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
                button(text: UserText.vpnFeedbackFormButtonDone, action: .cancel)
                    .keyboardShortcut(.defaultAction)
            } else {
                button(text: UserText.vpnFeedbackFormButtonCancel, action: .cancel)
                button(text: viewModel.viewState == .feedbackSending ? UserText.vpnFeedbackFormButtonSubmitting : UserText.vpnFeedbackFormButtonSubmit, action: .submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.submitButtonEnabled)
            }
        }
    }

    @ViewBuilder
    func button(text: String, action: VPNFeedbackFormViewModel.ViewAction) -> some View {
        Button(action: {
            Task {
                await viewModel.process(action: action)
            }
        }, label: {
            Text(text)
                .frame(maxWidth: .infinity)
        })
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }

}
