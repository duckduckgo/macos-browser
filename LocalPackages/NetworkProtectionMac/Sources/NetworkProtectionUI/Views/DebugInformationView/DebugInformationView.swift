//
//  DebugInformationView.swift
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
import Combine
import NetworkProtection

public struct DebugInformationView: View {

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.dismiss) private var dismiss

    // MARK: - Model

    /// The view model that this instance will use.
    ///
    @EnvironmentObject var model: DebugInformationViewModel

    // MARK: - View Contents

    public var body: some View {
        if model.showDebugInformation {
            Group {
                VStack(alignment: .leading, spacing: 0) {
                    informationRow(title: "Bundle Path", details: model.bundlePath)
                    informationRow(title: "Version", details: model.version)
                }

                Divider()
                    .padding(EdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9))
            }
        }
    }

    // MARK: - Composite Views

    private func informationRow(title: String, details: String) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                    .padding(.leading, 24)
                    .opacity(0.6)
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .fixedSize()

                Spacer()
            }

            HStack {
                Text(details)
                    .makeSelectable()
                    .multilineText()
                    .padding(.leading, 24)
                    .opacity(0.6)
                    .font(.system(size: 12, weight: .regular, design: .default))

                Spacer()
            }
        }
        .padding(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 9))
    }

    // MARK: - Rows

    private func dividerRow() -> some View {
        Divider()
            .padding(EdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9))
    }
}
