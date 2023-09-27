//
//  ShowTextCodeView.swift
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

struct ShowTextCodeView: View {
    @EnvironmentObject var model: ManagementDialogModel
    @State private var shareButtonFrame: CGRect = .zero // Store the frame of the share button

    var body: some View {
        SyncDialog(spacing: 20.0) {
            Text(UserText.showTextCodeTitle)
                .font(.system(size: 17, weight: .bold))
            VStack(alignment: .center, spacing: 20) {
                Text(UserText.showTextCodeCaption)
                    .multilineTextAlignment(.leading)
                SyncKeyView(text: model.codeToDisplay ?? "")
                    .frame(width: 213)
                HStack(alignment: .center, spacing: 10) {
                    Button {
                        if let code = model.codeToDisplay {
                            shareContent(code)
                        }
                    } label: {
                        HStack {
                            Image("Share")
                            Text(UserText.share)
                        }
                    }
                    .buttonStyle(CopyPasteButtonStyle())
                    .background(GeometryReader { geometry in
                                    Color.clear.onAppear {
                                        shareButtonFrame = geometry.frame(in: .global)
                                    }
                                })
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(model.codeToDisplay ?? "", forType: .string)
                    } label: {
                        HStack {
                            Image("Copy")
                            Text(UserText.copy)
                        }
                    }
                    .buttonStyle(CopyPasteButtonStyle())
                }
            }
            .padding(20)
            .frame(height: 256)
            .roundedBorder()
        } buttons: {
            Button("Done") {
                model.endFlow()
            }
        }
        .padding(.horizontal, 20)
    }

    private func shareContent(_ sharedText: String) {
        guard let shareButtonSuperview = NSApp.keyWindow?.contentView,
              let shareButtonGlobalFrame = NSApp.keyWindow?.convertToScreen(shareButtonFrame) else {
            return
        }
        let sharingPicker = NSSharingServicePicker(items: [sharedText])

        sharingPicker.show(relativeTo: shareButtonGlobalFrame, of: shareButtonSuperview, preferredEdge: .maxY)
    }
}
