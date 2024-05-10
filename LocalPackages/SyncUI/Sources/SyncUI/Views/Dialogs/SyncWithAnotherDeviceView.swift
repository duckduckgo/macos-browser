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

struct SyncWithAnotherDeviceView: View {

    @EnvironmentObject var model: ManagementDialogModel
    @EnvironmentObject var recoveryCodeModel: RecoveryCodeViewModel
    let code: String

    @State private var selectedSegment = 0
    @State private var showQRCode = true

    var body: some View {
        SyncDialog(spacing: 20.0) {
            Image(.syncPair96)
            SyncUIViews.TextHeader(text: UserText.syncWithAnotherDeviceTitle)
            if #available(macOS 12.0, *) {
                Text(syncWithAnotherDeviceInstruction)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            } else {
                Text(UserText.syncWithAnotherDeviceSubtitle(syncMenuPath: UserText.syncMenuPath))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }

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
            .frame(height: 332)
            .frame(minWidth: 380)
            .roundedBorder()

        }
    buttons: {
        Button(UserText.cancel) {
            model.endFlow()
        }
    }
    .frame(width: 420)
    }

    @available(macOS 12, *)
    private var syncWithAnotherDeviceInstruction: AttributedString {
        let baseString = UserText.syncWithAnotherDeviceSubtitle(syncMenuPath: UserText.syncMenuPath)
        var instructions = AttributedString(baseString)
        if let range = instructions.range(of: UserText.syncMenuPath) {
            instructions[range].font = .system(size: NSFont.systemFontSize, weight: .bold)
        }
        return instructions
    }

    fileprivate func pickerView() -> some View {
        return HStack(spacing: 0) {
            pickerOptionView(imageName: "QR-Icon", title: UserText.syncWithAnotherDeviceShowCodeButton, tag: 0)
            pickerOptionView(imageName: "Keyboard-16D", title: UserText.syncWithAnotherDeviceEnterCodeButton, tag: 1)
        }
        .frame(height: 32)
        .frame(minWidth: 348)
        .roundedBorder()
    }

    @ViewBuilder
    fileprivate func pickerOptionView(imageName: String, title: String, tag: Int) -> some View {
        Button {
            selectedSegment = tag
        } label: {
            HStack {
                Image(imageName)
                Text(title)
            }
            .frame(height: 28)
            .frame(minWidth: 172)
            .padding(.horizontal, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedSegment == tag ? Color(.blackWhite10) : .clear, lineWidth: 1)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedSegment == tag ? Color(.pickerViewSelected) : Color(.blackWhite1))
                }
            )
        }
        .buttonStyle(.plain)
    }

    fileprivate func scanQRCodeView() -> some View {
        return  Group {
            Text(UserText.syncWithAnotherDeviceShowQRCodeExplanation)
            QRCode(string: code, size: CGSize(width: 164, height: 164))
            Text(UserText.syncWithAnotherDeviceViewTextCode)
                .fontWeight(.semibold)
                .foregroundColor(Color(.linkBlue))
                .onTapGesture {
                    showQRCode = false
                }
        }
    }

    fileprivate func enterCodeView() -> some View {
        Group {
            Text(UserText.syncWithAnotherDeviceEnterCodeExplanation)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button {
                recoveryCodeModel.paste()
                model.delegate?.recoveryCodePasted(recoveryCodeModel.recoveryCode, fromRecoveryScreen: false)
            } label: {
                HStack {
                    Image(.paste)
                    Text(UserText.paste)
                }
            }
            .buttonStyle(CopyPasteButtonStyle(verticalPadding: 8.0))
            .keyboardShortcut(KeyEquivalent("v"), modifiers: .command)
        }
    }

    fileprivate func showTextCodeView() -> some View {
        Group {
            VStack(spacing: 20) {
                Text(UserText.syncWithAnotherDeviceShowCodeExplanation)
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
                            Image(.share)
                            Text(UserText.share)
                        }
                        .frame(width: 153, height: 28)
                    }
                    Button {
                        model.delegate?.copyCode()
                    } label: {
                        HStack {
                            Image(.copy)
                            Text(UserText.copy)
                        }
                        .frame(width: 153, height: 28)
                    }
                }
                .frame(width: 348, height: 32)
                Text(UserText.syncWithAnotherDeviceViewQRCode)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.linkBlue))
                    .onTapGesture {
                        showQRCode = true
                    }
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
