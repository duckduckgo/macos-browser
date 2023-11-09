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

public struct ShowTextCodeView: View {
    @EnvironmentObject var model: ManagementDialogModel
    @State private var shareButtonFrame: CGRect = .zero // Store the frame of the share button
    let code: String

    public init(code: String) {
        self.code = code
    }

    public var body: some View {
        SyncDialog(spacing: 20.0) {
            Text(UserText.showTextCodeTitle)
                .font(.system(size: 17, weight: .bold))
            VStack(alignment: .center, spacing: 20) {
                Text(UserText.showTextCodeCaption)
                    .multilineTextAlignment(.center)
                    .frame(width: 280)
                    .fixedSize()
                SyncKeyView(text: code)
                    .frame(width: 213)
                HStack(alignment: .center, spacing: 10) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                    } label: {
                        HStack {
                            Image("Copy")
                            Text(UserText.copy)
                        }
                    }
                    .buttonStyle(CopyPasteButtonStyle())
                    Button {
                        shareContent(code)
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
                }
            }
            .padding(20)
            .roundedBorder()
        } buttons: {
            Button(UserText.done) {
                model.endFlow()
            }
        }
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
