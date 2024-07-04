//
//  BookmarkSearchResultsView.swift
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

import Foundation
import SwiftUI

struct BookmarkSearchResultsView: View {

    @ObservedObject var viewModel: BookmarkSearchViewModel

    var body: some View {
        VStack {
            if viewModel.searchResult.isEmpty {
                Text("No results")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.searchResult, id: \.id) { bookmark in
                            BookmarkSearchResultCellView(bookmark: bookmark)
                                .frame(maxWidth: .infinity)
                                .padding(.leading, 8)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 408)
    }
}

struct BookmarkSearchResultCellView: View {
    let bookmark: BaseBookmarkEntity

    var body: some View {
        HStack {
            if let bookmark = bookmark as? Bookmark {
                let favicon = bookmark.favicon(.small) ?? .bookmarkDefaultFavicon
                Image(nsImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 16, height: 16)
                    .padding(.leading, 8)
            } else {
                Image(.folder)
                    .padding(.leading, 8)
            }

            Text(bookmark.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(.controlTextColor))
                .padding(.leading, 6)
            Spacer()
        }
        .frame(height: 28)
    }
}
