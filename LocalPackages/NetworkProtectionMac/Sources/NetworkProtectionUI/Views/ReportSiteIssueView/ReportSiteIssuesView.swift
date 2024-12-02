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
import PixelKit
import SwiftUI
import SwiftUIExtensions
import VPNPixels

struct ReportSiteIssuesView: ModalView {

    let domain: String
    @Environment(\.dismiss) private var dismiss

    let defaultAction: @MainActor (_ dismiss: () -> Void) -> Void
    let cancelAction: @MainActor (_ dismiss: () -> Void) -> Void
    let dontAskAgainAction: @MainActor (_ dismiss: () -> Void) -> Void

    public var body: some View {
        Dialog {
            Image(.siteBreakage128)

            Text(String(format: UserText.networkProtectionReportSiteIssuesViewTitle, domain))
                .font(Font.custom("SF Pro", size: 17)
                    .weight(.bold))
                .multilineText()

            Text(String(format: UserText.networkProtectionReportSiteIssuesViewDescription, domain))
                .font(Font.custom("SF Pro", size: 13))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .multilineText()

            Text(UserText.networkProtectionReportSiteIssuesViewFooter)
                .font(Font.custom("SF Pro", size: 11))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .multilineText()
        } buttons: {
            Button(UserText.networkProtectionReportSiteIssuesViewButtonDontAsk) {
                dontAskAgainAction(dismiss)
            }

            Spacer()

            Button(UserText.networkProtectionReportSiteIssuesViewButtonCancel) {
                cancelAction(dismiss)
            }

            Button(UserText.networkProtectionReportSiteIssuesViewButtonReport) {
                defaultAction(dismiss)
            }
        }
        .frame(width: 365)
    }
}
