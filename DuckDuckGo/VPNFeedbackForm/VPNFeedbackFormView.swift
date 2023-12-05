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

    struct ViewSize {
        fileprivate(set) var headerHeight: Double = 0.0
        fileprivate(set) var viewHeight: Double = 0.0
        fileprivate(set) var buttonsHeight: Double = 0.0

        var totalHeight: Double {
            return headerHeight + viewHeight + buttonsHeight + 80
        }
    }

    @EnvironmentObject var viewModel: VPNFeedbackFormViewModel

    let sizeChanged: (CGFloat) -> Void

    @State var viewSize: ViewSize = .init() {
        didSet {
            sizeChanged(viewSize.totalHeight)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                Text("Report an Issue")
                    .font(.title2)
            }
            .frame(height: 70)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.1))
            .background(
                GeometryReader { proxy in
                    Color.clear.onAppear {
                        viewSize.headerHeight = proxy.size.height
                    }
                }
            )

            Divider()

            switch viewModel.viewState {
            case .feedbackPending, .feedbackSending, .feedbackSendingFailed:
                VPNFeedbackFormBodyView()
                .padding([.top, .leading, .trailing], 20)
                .background(
                    GeometryReader { proxy in
                        Color.clear.onAppear {
                            viewSize.viewHeight = proxy.size.height
                        }
                    }
                )

                if viewModel.viewState == .feedbackSendingFailed {
                    Text("We couldn't send your feedback right now, please try again.")
                        .foregroundColor(.red)
                        .padding(.top, 15)
                }
            case .feedbackSent:
                VPNFeedbackFormSentView()
                    .padding([.top, .leading, .trailing], 20)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.onAppear {
                                viewSize.viewHeight = proxy.size.height
                            }
                        }
                    )
            }

            Spacer(minLength: 0)

            VPNFeedbackFormButtons()
                .padding(20)
                .background(
                    GeometryReader { proxy in
                        Color.clear.onAppear {
                            viewSize.buttonsHeight = proxy.size.height
                        }
                    }
                )
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
            case .unableToInstall:
                VPNFeedbackFormIssueDescriptionForm()
            case .failsToConnect:
                VPNFeedbackFormIssueDescriptionForm()
            case .tooSlow:
                VPNFeedbackFormIssueDescriptionForm()
            case .issueWithAppOrWebsite:
                VPNFeedbackFormIssueDescriptionForm()
            case .cantConnectToLocalDevice:
                VPNFeedbackFormIssueDescriptionForm()
            case .appCrashesOrFreezes:
                VPNFeedbackFormIssueDescriptionForm()
            case .featureRequest:
                VPNFeedbackFormIssueDescriptionForm()
            case .somethingElse:
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
                // TODO: Add macOS 11 editor
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

@available(macOS 12, *)
private struct FocusableTextEditor: View {

    @Binding var text: String
    @FocusState var isFocused: Bool

    let cornerRadius: CGFloat = 8.0
    let borderWidth: CGFloat = 0.4
    let characterLimit: Int = 10000

    var body: some View {
        TextEditor(text: $text)
            .frame(height: 150.0)
            .font(.body)
            .foregroundColor(.primary)
            .focused($isFocused)
            .padding(EdgeInsets(top: 3.0, leading: 6.0, bottom: 5.0, trailing: 0.0))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onChange(of: text) {
                text = String($0.prefix(characterLimit))
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.accentColor.opacity(0.5), lineWidth: 4).opacity(isFocused ? 1 : 0).scaleEffect(isFocused ? 1 : 1.04)
                        .animation(isFocused ? .easeIn(duration: 0.2) : .easeOut(duration: 0.0), value: isFocused)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color(NSColor.textEditorBorderColor), lineWidth: borderWidth)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(NSColor.textEditorBackgroundColor))
                }
            )
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
