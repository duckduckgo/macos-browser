//
//  SyncAnotherDeviceView.swift
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

public protocol SyncAnotherDeviceViewModel: ObservableObject {
    var recoveryCode: String? { get }

    func endFlow()
    func addAnotherDevice()
}

public struct SyncAnotherDeviceView<ViewModel>: View where ViewModel: SyncAnotherDeviceViewModel {
    @EnvironmentObject public var model: ViewModel
    @EnvironmentObject public var recoveryCodeModel: RecoveryCodeViewModel

    public init() {}

    enum Mode: Hashable {
        case showCode, enterCode
    }

    @State var selectedMode: Mode = .showCode

    public var body: some View {
        SyncDialog(spacing: 20.0) {
            Text(UserText.syncNewDevice)
                .font(.system(size: 17, weight: .bold))

            Picker("", selection: $selectedMode) {
                Text(UserText.showCode).tag(Mode.showCode)
                Text(UserText.enterCode).tag(Mode.enterCode)
            }
            .pickerStyle(.segmented)

            switch selectedMode {
            case .showCode:
                ShowCodeView<ViewModel>().environmentObject(model)
            case .enterCode:
                EnterCodeView(
                    instructions: UserText.syncNewDeviceEnterCodeInstructions,
                    buttonCaption: UserText.pasteFromClipboard
                )
                .environmentObject(recoveryCodeModel)
            }
        } buttons: {
            switch selectedMode {
            case .showCode:
                Button(UserText.cancel) {
                    model.endFlow()
                }
            case .enterCode:
                Button(UserText.cancel) {
                    model.endFlow()
                }
                Button(UserText.submit) {
                    model.addAnotherDevice()
                }
                .buttonStyle(DefaultActionButtonStyle(enabled: !recoveryCodeModel.shouldDisableSubmitButton))
                .disabled(recoveryCodeModel.shouldDisableSubmitButton)
            }
        }
        .frame(width: 480, height: 432)
    }

}

private struct ShowCodeView<ViewModel>: View where ViewModel: SyncAnotherDeviceViewModel {
    @EnvironmentObject var model: ViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text(UserText.syncNewDeviceShowCodeInstructions)
                .multilineTextAlignment(.center)

            HStack(alignment: .top, spacing: 20) {
                QRCode(string: model.recoveryCode ?? "", size: .init(width: 164, height: 164))

                VStack {
                    SyncKeyView(text: model.recoveryCode ?? "")

                    Spacer()

                    HStack {
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(model.recoveryCode ?? "", forType: .string)
                        } label: {
                            HStack {
                                Image("Copy")
                                Text(UserText.copy)
                            }
                        }
                        .buttonStyle(CopyPasteButtonStyle())
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(20)
        .roundedBorder()
    }
}
