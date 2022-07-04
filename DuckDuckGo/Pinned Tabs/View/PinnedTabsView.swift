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

struct PinnedTabsView: View {
    @ObservedObject var model: PinnedTabsModel
    @State private var draggedTab: Tab?

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(model.items) { item in
                PinnedTabView(model: item)
                    .opacity(draggedTab == item ? 0 : 1)
                    .onDrag({
                        draggedTab = item
                        return NSItemProvider(object: NSString())
                    }, previewIfAvailable: {
                        PinnedTabDraggingPreview(model: item)
                    })
                    .onDrop(of: ["public.utf8-plain-text"], delegate: PinnedTabsViewRelocateDragDelegate(
                        tab: item,
                        tabs: $model.items,
                        draggedTab: $draggedTab
                    ))
                    .environmentObject(model)
            }
        }
        .frame(maxHeight: PinnedTabView.Const.dimension)
    }
}

private extension View {

    @ViewBuilder
    func onDrag<V: View>(_ data: @escaping () -> NSItemProvider, previewIfAvailable: () -> V) -> some View {
        if #available(macOS 12.0, *) {
            onDrag(data, preview: previewIfAvailable)
        } else {
            onDrag(data)
        }
    }
}

struct PinnedTabsViewRelocateDragDelegate: DropDelegate {
    let tab: Tab
    @Binding var tabs: [Tab]
    @Binding var draggedTab: Tab?

    func dropEntered(info: DropInfo) {
        guard let currentTab = draggedTab else {
            return
        }
        if tab != currentTab,
           let from = tabs.firstIndex(of: currentTab),
           let to = tabs.firstIndex(of: tab),
           tabs[to] != currentTab {

            withAnimation(.easeInOut(duration: 0.2)) {
                tabs.move(fromOffsets: IndexSet(integer: from),
                          toOffset: to > from ? to + 1 : to)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        .init(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        print(#function, "has url: \(info.hasItemsConforming(to: ["public.url"]))")

//        if draggedTab == nil, let itemProvider = info.itemProviders(for: ["public.url"]).first {
//            itemProvider.loadItem(forTypeIdentifier: "public.url") { data, _ in
//                guard let data = data as? Data else {
//                    return
//                }
//                guard let url = String(bytes: data, encoding: .utf8)?.url else {
//                    return
//                }
//                DispatchQueue.main.async {
//                    TabDragAndDropManager.shared.dropToPinTabIfNeeded()
//                }
//            }
//        }

        draggedTab = nil
        return true
    }
}
