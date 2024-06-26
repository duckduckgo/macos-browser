//
//  SubscriptionAccessView.swift
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

import SwiftUI
import SwiftUIExtensions

public struct SubscriptionAccessView: View {

    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    private let model: SubscriptionAccessViewModel

    private let dismissAction: (() -> Void)?

    public init(model: SubscriptionAccessViewModel, dismiss: (() -> Void)? = nil) {
        self.model = model
        self.dismissAction = dismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {

                VStack(spacing: 8) {
                    Text(model.title)
                        .font(.title2)
                        .bold()
                        .foregroundColor(Color(.textPrimary))
                    Text(model.description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .fixMultilineScrollableText()
                        .foregroundColor(Color(.textPrimary))
                }

                Spacer().frame(height: 20)

                VStack(spacing: 0) {

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center, spacing: 8) {
                            Image("email-icon", bundle: .module)

                            Text(model.emailLabel)
                                .font(.system(size: 14, weight: .regular, design: .default))
                            Spacer()
                        }
                        .padding(.vertical, 10)

                        Text(model.emailDescription)
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(Color("TextSecondary", bundle: .module))
                            .fixMultilineScrollableText()

                        Button(model.emailButtonTitle) {
                            dismiss {
                                model.handleEmailAction()
                            }
                        }
                        .buttonStyle(DefaultActionButtonStyle(enabled: true))
                        .padding(.vertical, 16)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                }
                .roundedBorder()

                if model.shouldShowRestorePurchase {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.restorePurchaseDescription)
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(Color("TextSecondary", bundle: .module))
                            .fixMultilineScrollableText()
                        HStack {
                            TextButton(model.restorePurchaseButtonTitle) {
                                dismiss {
                                    model.handleRestorePurchaseAction()
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 20)
                }
            }
            .padding(20)

            Divider()

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(DismissActionButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 480)
    }

    private func dismiss(completion: (() -> Void)? = nil) {
        dismissAction?()
        presentationMode.wrappedValue.dismiss()

        if let completion = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                completion()
            }
        }
    }
}
