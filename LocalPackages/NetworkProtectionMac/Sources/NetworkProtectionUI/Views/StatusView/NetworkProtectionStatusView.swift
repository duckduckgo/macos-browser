//
//  NetworkProtectionStatusView.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import Combine
import NetworkProtection

extension View {
    func applyMenuAttributes() -> some View {
        opacity(0.9)
            .font(.system(size: 13, weight: .regular, design: .default))
            .foregroundColor(Color(.defaultText))
    }
}

public struct NetworkProtectionStatusView: View {

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    // MARK: - Model

    /// The view model that this instance will use.
    ///
    @EnvironmentObject var model: Model

    // MARK: - View Contents

    public var body: some View {
        VStack(spacing: 0) {
            if let warning = model.warningViewModel {
                WarningView(model: warning)
                    .transition(.slide)
            }

            if model.shouldShowSubscriptionExpired {
                SubscriptionExpiredView {
                    model.openPrivacyPro()
                } uninstallButtonHandler: {
                    model.uninstallVPN()
                }
                .padding(5)
            } else if let promptActionViewModel = model.promptActionViewModel {
                PromptActionView(model: promptActionViewModel)
                    .padding(.horizontal, 5)
                    .padding(.top, 5)
                    .transition(.slide)
            }

            Spacer()

            TunnelControllerView(model: model.tunnelControllerViewModel)
                .disabled(model.tunnelControllerViewDisabled)

            DebugInformationView()
                .transition(.slide)

            bottomMenuView()
        }
        .padding(5)
        .frame(width: 350, alignment: .top)
        .transition(.slide)
    }

    // MARK: - Composite Views

    private func bottomMenuView() -> some View {
        VStack(spacing: 0) {
            ForEach(model.menuItems(), id: \.uuid) { item in
                switch item {
                case .divider:
                    Divider()
                        .padding(EdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9))
                case .text(_, let icon, let title, let action):
                    MenuItemButton(icon: icon, title: title, textColor: Color(.defaultText)) {
                        await action()
                        dismiss()
                    }.applyMenuAttributes()
                }
            }
        }
    }
}
