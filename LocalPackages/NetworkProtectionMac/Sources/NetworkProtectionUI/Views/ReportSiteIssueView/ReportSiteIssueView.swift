//
//  ReportSiteIssuesView.swift
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

struct ReportSiteIssuesView: ModalView {
    enum ButtonsState {
        case compressed
        case expanded
    }

    let title: String
    let buttonsState: ButtonsState
    @Environment(\.dismiss) private var dismiss

    let domain: String
    let cancelActionTitle: String
    let cancelAction: @MainActor (_ dismiss: () -> Void) -> Void

    let defaultActionTitle: String
    @State
    private var isDefaultActionDisabled = true
    let defaultAction: @MainActor (_ dismiss: () -> Void) -> Void

    var body: some View {
        Dialog {
            Image(.siteBreakage128)

            Text("Report an issue with \(domain)?")
                .font(Font.custom("SF Pro", size: 17)
                    .weight(.bold))
                .multilineText()

            Text("Please let us know if you disabled the VPN for Hulu.com because you experienced issues.")
                .font(Font.custom("SF Pro", size: 13))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .multilineText()

            Text("Reports do not include any personalised information other than the domain address.")
                .font(Font.custom("SF Pro", size: 11))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .multilineText()
        } buttons: {
            Button("Don't Ask Again") {
                // no-op for now... change before merging
            }

            Spacer()

            Button("Not now") {
                cancelAction(dismiss)
            }

            Button("Report") {
                defaultAction(dismiss)
            }
        }
        .frame(width: 325)
    }
}
