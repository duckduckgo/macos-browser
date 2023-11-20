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
    @State private var showQRCode = true

    public init(code: String) {
        self.code = code
    }

    public var body: some View {
        SyncDialog(spacing: 20.0) {
            Image("Sync-Pair-96")
            Text("Sync With Another Device").bold()
                .font(Font.system(size: 17))
            Text("Go to Settings › Sync in the DuckDuckGo Browser on a another device and select Sync with Another Device.")
                .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                .multilineTextAlignment(.center)
            VStack(spacing: 20) {
                pickerView()
                if selectedSegment == 0 {
                    if showQRCode {
                        scanQRCodeView()
                    } else {
                        showTextCodeView()
                    }
                } else {
                    enterCodeView()
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 16)
            .frame(width: 380, height: 332)
            .roundedBorder()

        }
    buttons: {
        Button(UserText.cancel) {
            model.endDialogFlow()
        }
    }
    .frame(width: 420)
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
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedSegment == 0 ? Color("BlackWhite10") : .clear, lineWidth: 1)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedSegment == 0 ? Color("PickerViewSelected") : Color("BlackWhite1"))
                }
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
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedSegment == 1 ? Color("BlackWhite10") : .clear, lineWidth: 1)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedSegment == 1 ? Color("PickerViewSelected")  : Color("BlackWhite1"))
                }
            )
        }
        .frame(width: 348, height: 32)
        .roundedBorder()
    }

    fileprivate func scanQRCodeView() -> some View {
        return  Group {
            Text("Scan this QR code to connect with a mobile device.")
            QRCode(string: code, size: CGSize(width: 164, height: 164))
            HStack(spacing: 4) {
                Text("Desktop Users: ")
                HStack {
                    Text("View Text Code")
                        .fontWeight(.semibold)
                    Image("Arrow-Circle-Right-12")
                }
                .foregroundColor(Color("LinkBlueColor"))
                .onTapGesture {
                    showQRCode = false
                }
            }
            .frame(alignment: .center)
        }
    }

    fileprivate func enterCodeView() -> some View {
        return Group {
            Text("Enter the text code in the field below to connect")
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
                .frame(
                    width: 348,
                    height: recoveryCodeModel.recoveryCode.isEmpty ? 32 : 120
                )
            Button {
                recoveryCodeModel.paste()
                model.recoveryCodePasted(recoveryCodeModel.recoveryCode, fromRecoveryScreen: false)
            } label: {
                HStack {
                    Image("Paste")
                    Text("Paste")
                }
            }
            .buttonStyle(CopyPasteButtonStyle(verticalPadding: 8.0))
        }
    }

    fileprivate func showTextCodeView() -> some View {
        return Group {
            VStack(spacing: 20) {
                Text("Share this code to connect with a desktop machine.")
                Text(code)
                    .font(
                    Font.custom("SF Mono", size: 13)
                    .weight(.medium)
                    )
                    .kerning(2)
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    Button {
                        shareContent(code)
                    } label: {
                        HStack {
                            Image("Share")
                            Text("Share")
                        }
                        .frame(width: 153, height: 28)
                    }
                    Button {
                        model.copyCodeDesplayed()
                    } label: {
                        HStack {
                            Image("Copy")
                            Text("Copy")
                        }
                        .frame(width: 153, height: 28)
                    }
                }
                .frame(width: 348, height: 32)
                HStack(spacing: 4) {
                    Text("Mobile Users: ")
                    HStack {
                        Text("View QR Code")
                            .fontWeight(.semibold)
                        Image("Arrow-Circle-Right-12")
                    }
                    .foregroundColor(Color("LinkBlueColor"))
                    .onTapGesture {
                        showQRCode = true
                    }
                }
                .frame(alignment: .center)
            }
        }
        .frame(width: 348)
    }

    private func shareContent(_ sharedText: String) {
        guard let contentView = NSApp.keyWindow?.contentView else {
            return
        }
        let sharingPicker = NSSharingServicePicker(items: [sharedText])

        sharingPicker.show(relativeTo: contentView.frame, of: contentView, preferredEdge: .maxY)
    }
}


public protocol SyncWithAnotherDeviceManaging: ObservableObject {
    func cancelPressed()
    func copyCodeDesplayed()
    func recoveryCodePasted(_ code: String, fromRecoveryScreen: Bool)
}
