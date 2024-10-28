//
//  AddressBarTextFieldView.swift
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
import SwiftUIExtensions

struct AddressBarTextFieldView: NSViewRepresentable {

    @EnvironmentObject var addressBarModel: HomePage.Models.AddressBarModel
    @EnvironmentObject var settingsModel: HomePage.Models.SettingsModel

    /**
     * If this property is `true`, this view follows NTP custom background's
     * color scheme. It needs to be set to `false` for Burner Window that doesn't
     * support background customization.
     */
    let supportsFixedColorScheme: Bool

    init(supportsFixedColorScheme: Bool = true) {
        self.supportsFixedColorScheme = supportsFixedColorScheme
    }

    func makeNSView(context: Context) -> NSView {
        return addressBarModel.makeView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if supportsFixedColorScheme {
            switch settingsModel.customBackground?.colorScheme {
            case .light:
                nsView.appearance = NSAppearance(named: .aqua)
            case .dark:
                nsView.appearance = NSAppearance(named: .darkAqua)
            default:
                nsView.appearance = nil
            }
            nsView.subviews.forEach { $0.setNeedsDisplay($0.bounds) }
        }
    }
}

struct BigSearchBox: View {
    enum Const {
        static let searchBoxHeight = 40.0
        static let logoHeight = 96.0
        static let compactLogoHeight = 64.0
        static let spacing = 24.0
        static let logoSpacing = 12.0
        static let wordmarkHeight = 22.0

        static let searchBarWidth = 620.0

        static let totalHeight = searchBoxHeight + logoHeight + logoSpacing + wordmarkHeight + spacing
        static let compactHeight = searchBoxHeight + compactLogoHeight + spacing
    }

    let isCompact: Bool
    let supportsFixedColorScheme: Bool

    @EnvironmentObject var addressBarModel: HomePage.Models.AddressBarModel
    @Environment(\.colorScheme) private var colorScheme

    init(isCompact: Bool, supportsFixedColorScheme: Bool = true) {
        self.isCompact = isCompact
        self.supportsFixedColorScheme = supportsFixedColorScheme
    }

    var body: some View {
        VStack(spacing: Const.spacing) {
            logo()
            searchField()
        }
        .frame(width: Const.searchBarWidth)
    }

    @ViewBuilder
    func logo() -> some View {
        if isCompact {
            HStack(spacing: Const.logoSpacing) {
                Image(nsImage: .onboardingDax)
                    .resizable()
                    .frame(width: Const.compactLogoHeight, height: Const.compactLogoHeight)
                Image(nsImage: .duckDuckGoWordmark)
            }
        } else {
            VStack(spacing: Const.logoSpacing) {
                Image(nsImage: .onboardingDax)
                    .resizable()
                    .frame(width: Const.logoHeight, height: Const.logoHeight)
                Image(nsImage: .duckDuckGoWordmark)
            }
        }
    }

    @ViewBuilder
    func searchField() -> some View {
        ZStack {
            AddressBarTextFieldView(supportsFixedColorScheme: supportsFixedColorScheme)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 3)
                .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 0)
            if #available(macOS 12.0, *), addressBarModel.shouldDisplayInitialPlaceholder {
                HStack {
                    Text(UserText.addressBarPlaceholder)
                        .foregroundColor(Color(nsColor: NSColor.placeholderTextColor))
                        .background(Color.homePageAddressBarBackground)
                        .font(.system(size: 15))
                        .padding(.leading, 38)
                        .animation(.none, value: colorScheme) // don't animate color scheme change because NSTextField doesn't
                    Spacer()
                }
            }
        }
        .frame(height: Const.searchBoxHeight)
    }
}
