//
//  PinnedTabsView.swift
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

final class PinnedTabModel: ObservableObject, Identifiable, Hashable {
    static func == (lhs: PinnedTabModel, rhs: PinnedTabModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var isPlaceholder: Bool = false
    @Published var url: URL?
    @Published var faviconImage: NSImage?
}

struct PinnedTabView: View {
    enum Const {
        static let dimension: CGFloat = 32
    }

    @ObservedObject var model: PinnedTabModel
    @EnvironmentObject var collectionModel: PinnedTabsModel
    @State var isHovered: Bool = false

    var body: some View {
        Button {
            collectionModel.selectedItem = model
        } label: {
            ZStack {
                Rectangle()
                    .foregroundColor(foregroundColor)
                GeometryReader { proxy in
                    Rectangle()
                        .foregroundColor(Color("SeparatorColor"))
                        .frame(width: 1, height: 20)
                        .offset(x: proxy.size.width-1, y: 7)
                }
                if let image = model.faviconImage {
                    Image(nsImage: image)
                        .resizable()
                        .frame(maxWidth: 16, maxHeight: 16)
                        .aspectRatio(contentMode: .fit)
                }
            }
        }
        .buttonStyle(TouchDownButtonStyle())
        .frame(width: Const.dimension)
        .cornerRadius(6, corners: [.topLeft, .topRight])
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
}

struct PinnedTabsView: View {
    @ObservedObject var model: PinnedTabsModel

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(model.items, id: \.self) { item in
                PinnedTabView(model: item)
                    .environmentObject(model)
            }
        }
        .frame(maxHeight: PinnedTabView.Const.dimension)
    }
}
