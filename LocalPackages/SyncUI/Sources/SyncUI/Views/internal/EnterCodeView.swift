//
//  EnterCodeView.swift
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

struct EnterCodeView: View {

    let instructions: String
    let buttonCaption: String

    @EnvironmentObject var model: ManagementDialogModel
    @EnvironmentObject var recoveryCodeModel: RecoveryCodeViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text(instructions)
                .multilineTextAlignment(.center)

            SyncKeyView(text: recoveryCodeModel.recoveryCode)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .roundedBorder()
                .frame(maxWidth: 244)

            // This feels like business logic - should the models just talk directly to each other?
            Button {
                recoveryCodeModel.paste()
                if !recoveryCodeModel.recoveryCode.isEmpty {
                    model.delegate?.recoverDevice(using: recoveryCodeModel.recoveryCode)
                }
            } label: {
                HStack {
                    Image("Paste")
                    Text(buttonCaption)
                }
            }
            .buttonStyle(CopyPasteButtonStyle(verticalPadding: 8.0))
        }
        .padding(20)
        .roundedBorder()
    }
}
