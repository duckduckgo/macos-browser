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
import BrowserServicesKit

struct DataImportShortcutsView: ModalView {

    typealias DataType = DataImport.DataType

    @ObservedObject private var model: DataImportShortcutsViewModel

    init(model: DataImportShortcutsViewModel = DataImportShortcutsViewModel(), dataTypes: Set<DataType>? = nil) {
        self.init(model: .init(dataTypes: dataTypes))
    }

    init(model: DataImportShortcutsViewModel) {
        self.model = model
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                if let dataTypes = model.dataTypes, dataTypes.contains(.bookmarks), OnboardingActionsManager.isOnboardingFinished {
                    importShortcutsRow(image: Image(.bookmarksFavoritesColor24),
                                       title: UserText.importShortcutsBookmarksTitle,
                                       subtitle: UserText.importShortcutsBookmarksSubtitle,
                                       isOn: $model.showBookmarksBarStatus)
               }

                if let dataTypes = model.dataTypes, dataTypes.count > 1 {
                    Divider()
                        .padding(.leading)
                }

                importShortcutsRow(image: Image(.keyColor24),
                                   title: UserText.importShortcutsPasswordsTitle,
                                   subtitle: UserText.importShortcutsPasswordsSubtitle,
                                   isOn: $model.showPasswordsPinnedStatus)
            }
            .roundedBorder()
        }

        importShortcutsSubtitle()
    }
}

private func importShortcutsRow(image: Image, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
    HStack {
        image
        VStack(alignment: .leading) {
            Text(title)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.greyText)
        }
        .padding(.top, 0)
        .padding(.bottom, 1)
        Spacer()
        Toggle("", isOn: isOn)
            .toggleStyle(.switch)
    }
    .padding(.horizontal)
    .padding(.vertical, 10)
}

private func importShortcutsSubtitle() -> some View {
    Text(UserText.importDataShortcutsSubtitle)
        .font(.subheadline)
        .foregroundColor(Color(.greyText))
        .padding(.top, 8)
        .padding(.leading, 8)
}

#Preview {
    DataImportShortcutsView()
}
