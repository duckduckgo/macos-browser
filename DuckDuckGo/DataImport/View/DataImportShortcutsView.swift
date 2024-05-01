//
//  DataImportShortcutsView.swift
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

struct DataImportShortcutsView: ModalView {

    @ObservedObject var model: DataImportShortcutsViewModel

    init(model: DataImportShortcutsViewModel = DataImportShortcutsViewModel()) {
        self.model = model
    }

    var body: some View {

        VStack(spacing: 0) {
            HStack {
                Image(.bookmarksFavoritesColor24)
                VStack(alignment: .leading) {
                    Text("Show Bookmarks Bar", comment: "Title for the setting to enable the bookmarks bar")
                        .font(.system(size: 16))
                    Text("Put your favorite bookmarks in easy reach", comment: "Description for the setting to enable the bookmarks bar")
                        .font(.system(size: 13))
                        .foregroundColor(.greyText)
                }
                .padding(.top, 0)
                .padding(.bottom, 1)
                Spacer()
                Toggle("", isOn: $model.showBookmarksBarStatusBool)
                    .toggleStyle(.switch)
            }
            .padding()

            Divider()
                .padding(.leading)

            HStack {
                Image(.keyColor24)
                VStack(alignment: .leading) {
                    Text("Show Passwords Shortcut", comment: "Title for the setting to enable the passwords shortcut")
                        .font(.system(size: 16))
                    Text("Keep passwords nearby in the address bar", comment: "Description for the setting to enable the passwords shortcut")
                        .font(.system(size: 13))
                        .foregroundColor(.greyText)
                }
                .padding(.top, 0)
                .padding(.bottom, 1)

                Spacer()
                Toggle("", isOn: $model.showPasswordsPinnedStatusBool)
                    .toggleStyle(.switch)
            }
            .padding()
        }
        .roundedBorder()
    }
}

#Preview {
    DataImportShortcutsView()
}
