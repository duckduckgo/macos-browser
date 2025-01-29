//
//  BookmarkFavoriteView.swift
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
import SwiftUIExtensions
import PreferencesUI_macOS

struct BookmarkFavoriteView: View {
    @Binding var isFavorite: Bool

    var body: some View {
        Toggle(isOn: $isFavorite) {
            HStack(spacing: 6) {
                Image(.favoriteFilledBorder)
                Text(UserText.addToFavorites)
                    .foregroundColor(.primary)
            }
        }
        .toggleStyle(.checkbox)
        .accessibilityIdentifier("bookmark.add.add.to.favorites.button")
    }
}

#Preview("Favorite") {
    BookmarkFavoriteView(isFavorite: .constant(true))
        .frame(width: 300)
}

#Preview("Not Favorite") {
    BookmarkFavoriteView(isFavorite: .constant(false))
        .frame(width: 300)
}
