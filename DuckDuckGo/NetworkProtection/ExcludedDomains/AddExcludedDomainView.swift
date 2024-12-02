//
//  AddExcludedDomainView.swift
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
import SwiftUIExtensions

struct AddExcludedDomainView: ModalView {
    enum ButtonsState {
        case compressed
        case expanded
    }

    let title: String
    let buttonsState: ButtonsState

    @State
    private var domain = ""

    let cancelActionTitle: String
    let cancelAction: @MainActor (_ dismiss: () -> Void) -> Void

    let defaultActionTitle: String
    @State
    private var isDefaultActionDisabled = true
    let defaultAction: @MainActor (_ domain: String, _ dismiss: () -> Void) -> Void

    var body: some View {
        TieredDialogView(
            verticalSpacing: 16.0,
            horizontalPadding: 20.0,
            top: {
                Text(title)
                    .foregroundColor(.primary)
                    .fontWeight(.semibold)
                    .padding(.top, 20)
            },
            center: {
                form
            },
            bottom: {
                AddExcludedDomainButtonsView(
                    viewState: .init(buttonsState),
                    otherButtonAction: .init(
                        title: cancelActionTitle,
                        keyboardShortCut: .cancelAction,
                        isDisabled: false,
                        action: cancelAction
                    ), defaultButtonAction: .init(
                        title: defaultActionTitle,
                        keyboardShortCut: .defaultAction,
                        isDisabled: isDefaultActionDisabled,
                        action: { dismiss in
                            defaultAction(domain, dismiss)
                        }
                    )
                ).padding(.bottom, 16.0)
            }
        ).font(.system(size: 13))
            .frame(width: 420)
    }

    var form: some View {
        TwoColumnsListView(
            horizontalSpacing: 16.0,
            verticalSpacing: 20.0,
            rowHeight: 22.0,
            leftColumn: {
                Text("URL")
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
            },
            rightColumn: {
                TextField("", text: $domain)
                    .focusedOnAppear()
                    .onChange(of: domain) { domain in
                        guard let url = URL(trimmedAddressBarString: domain) else { return }
                        isDefaultActionDisabled = domain.trimmingWhitespace().isEmpty || !url.isValid
                    }
                    .accessibilityIdentifier("bookmark.add.name.textfield")
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 14))
            }
        )
    }
}

private extension AddExcludedDomainButtonsView.ViewState {

    init(_ state: AddExcludedDomainView.ButtonsState) {
        switch state {
        case .compressed:
            self = .compressed
        case .expanded:
            self = .expanded
        }
    }
}
