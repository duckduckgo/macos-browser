//
//  SaveRecoveryPDFView.swift
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

struct SaveRecoveryPDFView: View {
    @EnvironmentObject var viewModel: ManagementDialogModel
    let code: String

    var body: some View {
        SyncDialog {
            VStack(spacing: 20.0) {
                Image(.syncRecoveryPDF)
                SyncUIViews.TextHeader(text: UserText.saveRecoveryPDF)
                SyncUIViews.TextDetailMultiline(text: UserText.recoveryPDFExplanation)
            }
            VStack(alignment: .leading, spacing: 20) {
                Text(code)
                    .kerning(2)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(5)
                    .lineLimit(3)
                    .font(Font.custom("SF Mono", size: 12))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 340)
                HStack {
                    Button {
                        viewModel.delegate?.copyCode()
                    } label: {
                        Text(UserText.recoveryPDFCopyCodeButton)
                            .frame(width: 155, height: 28)
                    }
                    Button {
                        viewModel.delegate?.saveRecoveryPDF()
                    } label: {
                        Text(UserText.recoveryPDFSavePDFButton)
                            .frame(width: 155, height: 28)
                    }
                }
                .frame(width: 340)
            }
            .padding(20)
            .roundedBorder()
            .padding(20)

            Text(UserText.recoveryPDFWarning)
                .foregroundColor(Color(.blackWhite60))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } buttons: {
            Button(UserText.next) {
                viewModel.delegate?.recoveryCodeNextPressed()
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .frame(width: 420)
    }
}
