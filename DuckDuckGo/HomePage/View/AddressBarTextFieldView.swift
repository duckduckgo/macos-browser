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

    let usesFixedColorScheme: Bool

    init(usesFixedColorScheme: Bool = true) {
        self.usesFixedColorScheme = usesFixedColorScheme
    }

    func makeNSView(context: Context) -> NSView {
        return addressBarModel.makeView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if usesFixedColorScheme {
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
        static let spacing = 24.0

        static let totalHeight = searchBoxHeight + logoHeight + spacing
    }

    let usesFixedColorScheme: Bool

    init(usesFixedColorScheme: Bool = true) {
        self.usesFixedColorScheme = usesFixedColorScheme
    }

    var body: some View {
        VStack(spacing: Const.spacing) {
            logo()
            searchField()
        }
    }

    @ViewBuilder
    func logo() -> some View {
        Image(nsImage: .onboardingDax)
            .resizable()
            .frame(width: Const.logoHeight, height: Const.logoHeight)
    }

    @ViewBuilder
    func searchField() -> some View {
        AddressBarTextFieldView(usesFixedColorScheme: usesFixedColorScheme)
            .frame(height: Const.searchBoxHeight)
            .shadow(color: Color.blackWhite100.opacity(0.1), radius: 2, x: 0, y: 2)
    }
}
