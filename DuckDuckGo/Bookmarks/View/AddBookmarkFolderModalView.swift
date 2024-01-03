//
//  AddBookmarkFolderModalView.swift
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

import SwiftUI

struct AddBookmarkFolderModalView: View {

    @State var model: AddBookmarkFolderModalViewModel = .init()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Folder", comment: "Title for New bookmark folder dialog")
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                Text("Name:", comment: "New bookmark folder dialog folder name field heading")
                    .frame(height: 22)

                TextField("", text: $model.folderName)
                    .accessibilityIdentifier("Title Text Field")
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
            }
            .padding(.bottom, 4)

            HStack {
                Spacer()

                Button(UserText.cancel) {
                    model.cancel(dismiss: dismiss.callAsFunction)
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    model.addFolder(dismiss: dismiss.callAsFunction)
                } label: {
                    Text("Add", comment: "Button to confim a folder creation")

                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isAddButtonDisabled)

            }
        }
        .font(.system(size: 13))
        .padding()
        .frame(width: 450, height: 131)
    }

    @MainActor
    func show(in window: NSWindow? = nil, completion: (() -> Void)? = nil) {

        guard let window = window ?? WindowControllersManager.shared.lastKeyMainWindowController?.window else { return }

        if !window.isKeyWindow {
            window.makeKeyAndOrderFront(nil)
        }

        let sheetWindow = SheetHostingWindow(rootView: self)

        window.beginSheet(sheetWindow, completionHandler: completion.map { completion in { _ in
            completion()
        }
        })
    }

}

#Preview {
    AddBookmarkFolderModalView()
}
