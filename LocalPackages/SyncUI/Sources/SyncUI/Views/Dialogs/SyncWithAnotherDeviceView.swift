//
//  SyncWithAnotherDeviceView.swift
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

public struct SyncWithAnotherDeviceView<ViewModel>: View where ViewModel: ManagementViewModel {

    @EnvironmentObject var model: ViewModel
    @EnvironmentObject var recoveryCodeModel: RecoveryCodeViewModel
    let code: String

    @State private var selectedSegment = 0

    public init(code: String) {
        self.code = code
    }

    fileprivate func pickerView() -> some View {
        return HStack(spacing: 0) {
            HStack {
                Image("QR-Icon")
                Text("Show Code")
            }
            .onTapGesture {
                selectedSegment = 0
            }
            .frame(width: 172, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedSegment == 0 ? Color.white : Color("BlackWhite1"))
            )
            HStack {
                Image("Keyboard-16D")
                Text("Enter Code")
            }
            .onTapGesture {
                selectedSegment = 1
            }
            .frame(width: 172, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedSegment == 1 ? Color.white : Color("BlackWhite1"))
            )
        }
        .frame(width: 348, height: 32)
        .roundedBorder()
    }

    public var body: some View {
        SyncDialog(spacing: 20.0) {
            Image("Sync-Pair-96x96")
            Text("Sync With Another Device").bold()
            Text("Go to Settings › Sync in the DuckDuckGo Browser on a another device and select Sync with Another Device.")
                .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                .multilineTextAlignment(.center)
            VStack(spacing: 16.0) {
                pickerView()
                if selectedSegment == 0 {
                    Text("Scan this QR code to connect with a mobile device.")
                    QRCode(string: code, size: CGSize(width: 220, height: 220))
                    HStack(spacing: 4) {
                        Text("Desktop Users: ")
                        HStack {
                            Text("View Text Code")
                                .fontWeight(.semibold)
                            Image("Arrow-Circle-Right-12")
                        }
                        .foregroundColor(Color("LinkBlueColor"))
                    }
                    .frame(alignment: .center)
                } else {
                    Text("Enter the text code in the field below to connect")
                    SyncKeyView(text: recoveryCodeModel.recoveryCode)
                        .frame(width: 284, height: 210)
                        .background(ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("BookmarkRepresentingColor4"), lineWidth: 5)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white)
                        })

                    Button {
                        recoveryCodeModel.paste()
                        model.recoveryCodePasted(recoveryCodeModel.recoveryCode)
                    } label: {
                        HStack {
                            Image("Paste")
                            Text("Paste")
                        }
                    }
                    .buttonStyle(CopyPasteButtonStyle(verticalPadding: 8.0))
                }
            }
            .frame(width: 380, height: 390)
            .roundedBorder()

        }
    buttons: {
        Button(UserText.cancel) {
            model.endDialogFlow()
        }
    }
    .frame(width: 420)
    .background(Color.white)
    }
}
