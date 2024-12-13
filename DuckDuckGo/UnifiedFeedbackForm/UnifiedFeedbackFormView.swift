//
//  UnifiedFeedbackFormView.swift
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

struct UnifiedFeedbackFormView: View {

    @EnvironmentObject var viewModel: UnifiedFeedbackFormViewModel

    var body: some View {
        VStack(spacing: 0) {
            Group {
                Text(UserText.feedbackFormTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(height: 70)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.1))

            Divider()

            switch viewModel.viewState {
            case .feedbackPending, .feedbackSending, .feedbackSendingFailed:
                FeedbackFormBodyView()
                    .padding([.top, .leading, .trailing], 20)

                if viewModel.viewState == .feedbackSendingFailed {
                    Text(UserText.vpnFeedbackFormSendingConfirmationError)
                        .foregroundColor(.red)
                        .padding(.top, 15)
                }
            case .feedbackSent:
                FeedbackFormSentView()
                    .padding([.top, .leading, .trailing], 20)
            }

            Spacer(minLength: 0)

            FeedbackFormButtons()
                .padding(20)
        }
        .onChange(of: viewModel.needsSubmitShowReport) { needsSubmitShowReport in
            if needsSubmitShowReport {
                Task {
                    await viewModel.process(action: .reportSubmitShow)
                }
            }
        }
        .task {
            await viewModel.process(action: .reportShow)
        }
    }

}

private struct FeedbackFormBodyView: View {

    @EnvironmentObject var viewModel: UnifiedFeedbackFormViewModel

    var body: some View {
        CategoryPicker(options: UnifiedFeedbackReportType.allCases, selection: $viewModel.selectedReportType) {
            switch UnifiedFeedbackReportType(rawValue: viewModel.selectedReportType) {
            case .selectReportType, nil:
                EmptyView()
            case .general:
                FeedbackFormIssueDescriptionView {
                    Text(UserText.pproFeedbackFormGeneralFeedbackPlaceholder)
                }
            case .requestFeature:
                FeedbackFormIssueDescriptionView {
                    Text(UserText.pproFeedbackFormRequestFeaturePlaceholder)
                }
            case .reportIssue:
                reportProblemView()
            }
        }
    }

    @ViewBuilder
    func reportProblemView() -> some View {
        CategoryPicker(options: viewModel.availableCategories, selection: $viewModel.selectedCategory) {
            switch UnifiedFeedbackCategory(rawValue: viewModel.selectedCategory) {
            case .selectFeature, nil:
                EmptyView()
            case .subscription:
                CategoryPicker(options: PrivacyProFeedbackSubcategory.allCases, selection: $viewModel.selectedSubcategory) {
                    issueDescriptionView()
                }
            case .vpn:
                CategoryPicker(options: VPNFeedbackSubcategory.allCases, selection: $viewModel.selectedSubcategory) {
                    issueDescriptionView()
                }
            case .pir:
                CategoryPicker(options: PIRFeedbackSubcategory.allCases, selection: $viewModel.selectedSubcategory) {
                    issueDescriptionView()
                }
            case .itr:
                CategoryPicker(options: ITRFeedbackSubcategory.allCases, selection: $viewModel.selectedSubcategory) {
                    issueDescriptionView()
                }
            }
        }
    }

    @ViewBuilder
    func issueDescriptionView() -> some View {
        FeedbackFormIssueDescriptionView {
            Text(LocalizedStringKey(UserText.pproFeedbackFormText1))
                .onURLTap { _ in
                    Task {
                        await viewModel.process(action: .reportFAQClick)
                        await viewModel.process(action: .faqClick)
                    }
                }
        } content: {
            Text(UserText.pproFeedbackFormEmailLabel)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            TextField(UserText.pproFeedbackFormEmailPlaceholder, text: $viewModel.userEmail)
                .textFieldStyle(.roundedBorder)
        } footer: {
            Text(UserText.pproFeedbackFormText2)
            VStack(alignment: .leading) {
                Text(UserText.pproFeedbackFormText3)
                Text(UserText.pproFeedbackFormText4)
            }
            Text(UserText.pproFeedbackFormText5)
        }
    }
}

private struct CategoryPicker<Category: FeedbackCategoryProviding, Content: View>: View where Category.AllCases == [Category], Category.RawValue == String {
    let options: [Category]
    let selection: Binding<String>
    let content: () -> Content

    init(options: [Category],
         selection: Binding<String>,
         @ViewBuilder content: @escaping () -> Content) {
        self.options = options
        self.selection = selection
        self.content = content
    }

    var body: some View {
        Group {
            Picker(selection: selection, content: {
                ForEach(options) { option in
                    Text(option.displayName).tag(option.rawValue)
                }
            }, label: {})
            .controlSize(.large)
            .padding(.bottom, 0)

            if Category(rawValue: selection.wrappedValue) == .prompt {
                Spacer()
                    .frame(height: 50)
            } else {
                content()
            }
        }
    }
}

private struct FeedbackFormIssueDescriptionView<Label: View, Content: View, Footer: View>: View {
    @EnvironmentObject var viewModel: UnifiedFeedbackFormViewModel

    let label: () -> Label
    let content: () -> Content
    let footer: () -> Footer

    init(@ViewBuilder label: @escaping () -> Label,
         @ViewBuilder content: @escaping () -> Content,
         @ViewBuilder footer: @escaping () -> Footer) {
        self.label = label
        self.content = content
        self.footer = footer
    }

    init(@ViewBuilder label: @escaping () -> Label,
         @ViewBuilder footer: @escaping () -> Footer) where Content == EmptyView {
        self.init {
            label()
        } content: {
            EmptyView()
        } footer: {
            footer()
        }
    }

    init(@ViewBuilder label: @escaping () -> Label) where Content == EmptyView, Footer == Text {
        self.init {
            label()
        } content: {
            EmptyView()
        } footer: {
            Text(UserText.pproFeedbackFormDisclaimer)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            label()
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            textEditor()
            content()
            footer()
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

private struct FeedbackFormSentView: View {

    var body: some View {
        VStack(spacing: 0) {
            Image(.vpnFeedbackSent)
                .padding(.top, 20)

            Text(UserText.pproFeedbackFormSendingConfirmationTitle)
                .font(.system(size: 18, weight: .medium))
                .padding(.top, 30)

            Text(UserText.pproFeedbackFormSendingConfirmationDescription)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
    }

}

private struct FeedbackFormButtons: View {

    @EnvironmentObject var viewModel: UnifiedFeedbackFormViewModel

    var body: some View {
        HStack {
            if viewModel.viewState == .feedbackSent {
                button(text: UserText.pproFeedbackFormButtonDone, action: .cancel)
                    .keyboardShortcut(.defaultAction)
            } else {
                button(text: UserText.pproFeedbackFormButtonCancel, action: .cancel)
                button(text: viewModel.viewState == .feedbackSending ? UserText.pproFeedbackFormButtonSubmitting : UserText.pproFeedbackFormButtonSubmit, action: .submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.submitButtonEnabled)
            }
        }
    }

    @ViewBuilder
    func button(text: String, action: UnifiedFeedbackFormViewModel.ViewAction) -> some View {
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
