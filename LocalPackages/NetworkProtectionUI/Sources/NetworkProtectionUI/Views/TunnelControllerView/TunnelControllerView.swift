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

fileprivate extension Font {
    enum NetworkProtection {
        static var connectionStatusDetail: Font {
            .system(size: 13, weight: .regular, design: .default)
        }

        static var content: Font {
            .system(size: 13, weight: .regular, design: .default)
        }

        static var description: Font {
            .system(size: 13, weight: .regular, design: .default)
        }

        static var label: Font {
            .system(size: 13, weight: .regular, design: .default)
        }

        static var sectionHeader: Font {
            .system(size: 12, weight: .semibold, design: .default)
        }

        static var timer: Font {
            .system(size: 13, weight: .regular, design: .default)
            .monospacedDigit()
        }

        static var title: Font {
            .system(size: 15, weight: .semibold, design: .default)
        }
    }
}

private enum Opacity {
    static func connectionStatusDetail(colorScheme: ColorScheme) -> Double {
        colorScheme == .light ? Double(0.6) : Double(0.5)
    }

    static let content = Double(0.58)
    static let label = Double(0.9)
    static let description = Double(0.9)
    static let link = Double(1)

    static func sectionHeader(colorScheme: ColorScheme) -> Double {
        colorScheme == .light ? Double(0.84) : Double(0.85)
    }

    static func timer(colorScheme: ColorScheme) -> Double {
        colorScheme == .light ? Double(0.6) : Double(0.5)
    }

    static func title(colorScheme: ColorScheme) -> Double {
        colorScheme == .light ? Double(0.84) : Double(0.85)
    }
}

fileprivate extension View {
    func applyConnectionStatusDetailAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.connectionStatusDetail(colorScheme: colorScheme))
            .font(.NetworkProtection.connectionStatusDetail)
            .foregroundColor(Color(.defaultText))
    }

    func applyContentAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.content)
            .font(.NetworkProtection.content)
            .foregroundColor(Color(.defaultText))
    }

    func applyDescriptionAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.description)
            .font(.NetworkProtection.description)
            .foregroundColor(Color(.defaultText))
    }

    func applyLabelAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.label)
            .font(.NetworkProtection.label)
            .foregroundColor(Color(.defaultText))
    }

    func applySectionHeaderAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.sectionHeader(colorScheme: colorScheme))
            .font(.NetworkProtection.sectionHeader)
            .foregroundColor(Color(.defaultText))
    }

    func applyTimerAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.timer(colorScheme: colorScheme))
            .font(.NetworkProtection.timer)
            .foregroundColor(Color(.defaultText))
    }

    func applyTitleAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.title(colorScheme: colorScheme))
            .font(.NetworkProtection.title)
            .foregroundColor(Color(.defaultText))
    }
}

public struct TunnelControllerView: View {

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    // MARK: - Model

    /// The view model that this instance will use.
    ///
    @ObservedObject var model: TunnelControllerViewModel

    // MARK: - Initializers

    public init(model: TunnelControllerViewModel) {
        self.model = model
    }

    // MARK: - View Contents

    public var body: some View {
        Group {
            headerView()

            featureToggleRow()

            Divider()
                .padding(EdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9))

            if model.showServerDetails {
                connectionStatusView()
            }
        }
    }

    // MARK: - Composite Views

    /// Main image, feature ON/OFF and feature description
    ///
    private func headerView() -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Image(model.mainImageAsset)
                Spacer()
            }

            Text(model.featureStatusDescription)
                .applyTitleAttributes(colorScheme: colorScheme)
                .padding([.top], 8)
                .multilineText()

            Text(UserText.networkProtectionStatusViewFeatureDesc)
                .multilineText()
                .multilineTextAlignment(.center)
                .applyDescriptionAttributes(colorScheme: colorScheme)
                .fixedSize(horizontal: false, vertical: true)
                .padding(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
        }
    }

    /// Connection status: server IP address and location
    ///
    private func connectionStatusView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(UserText.networkProtectionStatusViewConnDetails)
                .applySectionHeaderAttributes(colorScheme: colorScheme)
                .padding(EdgeInsets(top: 6, leading: 9, bottom: 6, trailing: 9))

            connectionStatusRow(icon: .serverLocationIcon,
                                title: UserText.networkProtectionStatusViewLocation,
                                details: model.serverLocation)
            connectionStatusRow(icon: .ipAddressIcon,
                                title: UserText.networkProtectionStatusViewIPAddress,
                                details: model.serverAddress)

            dividerRow()
        }
    }

    // MARK: - Rows

    private func dividerRow() -> some View {
        Divider()
            .padding(EdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9))
    }

    private func featureToggleRow() -> some View {
        Toggle(isOn: model.isToggleOn) {
            HStack {
                Text(UserText.networkProtectionStatusViewConnLabel)
                    .applyLabelAttributes(colorScheme: colorScheme)
                    .frame(alignment: .leading)
                    .fixedSize()

                Spacer(minLength: 8)

                Text(model.connectionStatusDescription)
                    .applyTimerAttributes(colorScheme: colorScheme)
                    .fixedSize()

                Spacer()
                    .frame(width: 8)
            }
        }
        .disabled(model.isToggleDisabled)
        .toggleStyle(.switch)
        .padding(EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9))
    }

    private func connectionStatusRow(icon: NetworkProtectionAsset, title: String, details: String) -> some View {
        HStack(spacing: 0) {
            Image(icon)
                .padding([.trailing], 8)

            Text(title)
                .applyLabelAttributes(colorScheme: colorScheme)
                .fixedSize()

            Spacer(minLength: 16)

            Text(details)
                .makeSelectable()
                .applyConnectionStatusDetailAttributes(colorScheme: colorScheme)
                .fixedSize()
        }
        .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 9))
    }
}
