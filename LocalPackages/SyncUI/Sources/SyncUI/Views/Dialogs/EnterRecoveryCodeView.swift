//
//  EnterRecoveryCodeView.swift
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

public struct EnterRecoveryCodeView: View {
    @EnvironmentObject var model: ManagementDialogModel
    @EnvironmentObject var recoveryCodeModel: RecoveryCodeViewModel
    let code: String

    public init(code: String) {
        self.code = code
    }

    public var body: some View {
        SyncDialog(spacing: 20.0) {
            Image("Lock-Succes-96")
            SyncUIConstants.TextHeader(text: UserText.enterRecoveryCodeDialogTitle)
            SyncUIConstants.TextDetailMultiline(text: UserText.enterRecoveryCodeDialogSubtitle)
            VStack(spacing: 16) {
                Text(UserText.enterRecoveryCodeDialogAction1)
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("BookmarkRepresentingColor4"), lineWidth: 5)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.clear)
                        Text(recoveryCodeModel.recoveryCode)
                            .font(
                                Font.custom("SF Mono", size: 13)
                                    .weight(.medium)
                            )
                            .kerning(2)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal)
                    }
                    .frame(width: 290, height: 32)
                    Button {
                        recoveryCodeModel.paste()
                        model.delegate?.recoveryCodePasted(recoveryCodeModel.recoveryCode, fromRecoveryScreen: true)
                    } label: {
                        Image("Paste")
                            .frame(width: 32, height: 32)
                    }
                }
                .frame(width: 348)
            }
            .padding()
            .roundedBorder()
            .padding()
            HStack {
                line()
                Text(UserText.enterRecoveryCodeDialogAction2)
                    .frame(width: 184)
                    .fixedSize()
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color("BlackWhite60"))
                line()
            }
            QRCode(string: code, size: CGSize(width: 192, height: 192))
        } buttons: {
            Button(UserText.cancel) {
                model.endFlow()
            }
            .buttonStyle(DismissActionButtonStyle())
        }
        .frame(width: 420)
    }

    func line() -> some View {
        return Rectangle()
            .foregroundColor(.clear)
            .frame(maxWidth: .infinity, minHeight: 0.5, maxHeight: 0.5)
            .background(Color("BlackWhite10"))
    }
}
