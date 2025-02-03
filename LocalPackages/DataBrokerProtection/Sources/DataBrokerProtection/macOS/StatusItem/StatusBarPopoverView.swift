//
//  StatusBarPopoverView.swift
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
import Combine
import SwiftUIExtensions

struct StatusBarPopoverView: View {
    let viewModel: StatusBarMenuDebugInfoViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            HStack {
                Text("Personal Information Removal")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }

            informationRow(title: "Version", details: viewModel.version)
            informationRow(title: "Bundle Path", details: viewModel.bundlePath)
        }
        .padding()
        .frame(width: 350, height: 200)
    }

    private func informationRow(title: String, details: String) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            HStack {

                Text(details)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .makeSelectable()
                    .lineLimit(nil)
             Spacer()
            }
        }
    }
}

#Preview {
    StatusBarPopoverView(viewModel: StatusBarMenuDebugInfoViewModel())
}
