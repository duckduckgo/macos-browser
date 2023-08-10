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

        static var menu: Font {
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
    static let menu = Double(0.9)
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

    func applyMenuAttributes() -> some View {
        opacity(Opacity.menu)
            .font(.NetworkProtection.menu)
            .foregroundColor(Color(.defaultText))
    }

    func applyLinkAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.link)
            .font(.NetworkProtection.content)
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

public struct NetworkProtectionStatusView: View {

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    // MARK: - Model

    /// The view model that this instance will use.
    ///
    @ObservedObject var model: Model

    // MARK: - Initializers

    public init(model: Model) {
        self.model = model
    }

    // MARK: - View Contents

    public var body: some View {
        VStack(spacing: 0) {
            if let healthWarning = model.issueDescription {
                connectionHealthWarningView(message: healthWarning)
            }

            Spacer()

            TunnelControllerView(model: model.tunnelControllerViewModel)

            bottomMenuView()
        }
        .padding(5)
        .frame(maxWidth: 350, alignment: .top)
    }

    // MARK: - Composite Views

    private func connectionHealthWarningView(message: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image("WarningColored", bundle: Bundle.module)

                /// Text elements in SwiftUI don't expand horizontally more than needed, so we're adding an "optional" spacer at the end so that
                /// the alert bubble won't shrink if there's not enough text.
                HStack(spacing: 0) {
                    Text(message)
                        .makeSelectable()
                        .multilineText()
                        .foregroundColor(Color(.defaultText))

                    Spacer()
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color("AlertBubbleBackground", bundle: Bundle.module)))
        }
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 4, trailing: 8))
    }

    private func bottomMenuView() -> some View {
        VStack(spacing: 0) {
            ForEach(model.menuItems, id: \.name) { menuItem in
                MenuItemButton(menuItem.name, textColor: Color(.defaultText)) {
                    await menuItem.action()
                    dismiss()
                }
            }
        }
    }
}
