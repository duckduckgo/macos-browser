//
//  PinnedTabView.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

struct PinnedTabView: View {
    enum Const {
        static let dimension: CGFloat = 32
    }

    @ObservedObject var model: Tab
    @EnvironmentObject var collectionModel: PinnedTabsModel
    @State var isHovered: Bool = false

    var body: some View {
        Button {
            if collectionModel.selectedItem != model {
                collectionModel.selectedItem = model
            }
        } label: {
            PinnedTabInnerView(foregroundColor: foregroundColor, faviconImage: model.favicon)
        }
        .buttonStyle(TouchDownButtonStyle())
        .cornerRadius(6, corners: [.topLeft, .topRight])
        .contextMenu(contextMenu)
        .onHover { isHovered in
            self.isHovered = isHovered
        }
    }

    var foregroundColor: Color {
        if collectionModel.selectedItem == model {
            return Color("InterfaceBackgroundColor")
        }
        return isHovered ? Color("TabMouseOverColor") : Color.clear
    }

    let contextMenu = ContextMenu {
        Button {
            print("unpin")
        } label: {
            Text(UserText.unpinTab)
        }
        Button {
            print("duplicate")
        } label: {
            Text(UserText.duplicateTab)
        }
        Divider()
        Button {
            print("bookmark")
        } label: {
            Text(UserText.bookmarkThisPage)
        }
        Button {
            print("close")
        } label: {
            Text(UserText.closeTab)
        }
    }
}

struct PinnedTabInnerView: View {
    var foregroundColor: Color
    var faviconImage: NSImage?

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(foregroundColor)
            GeometryReader { proxy in
                Rectangle()
                    .foregroundColor(Color("SeparatorColor"))
                    .frame(width: 1, height: 20)
                    .offset(x: proxy.size.width-1, y: 7)
            }
            if let image = faviconImage {
                Image(nsImage: image)
                    .resizable()
                    .frame(maxWidth: 16, maxHeight: 16)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(width: PinnedTabView.Const.dimension)
    }
}

struct PinnedTabDraggingPreview: View {
    @ObservedObject var model: Tab

    var body: some View {
        PinnedTabInnerView(foregroundColor: Color("InterfaceBackgroundColor"), faviconImage: model.favicon)
            .cornerRadius(6)
    }
}
