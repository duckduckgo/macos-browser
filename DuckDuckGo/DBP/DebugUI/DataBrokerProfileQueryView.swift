//
//  DataBrokerProfileQueryView.swift
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

struct DataBrokerProfileQueryView: View {
    let items = ["Item 1", "Item 2", "Item 3"]
    @State private var selectedItem: String?

    var body: some View {
        NavigationView {
            List(items, id: \.self) { item in
                NavigationLink(destination: DetailView(item: item)) {
                    Text(item)
                }
            }
            .frame(minWidth: 200)

            if let selectedItem = selectedItem {
                DetailView(item: selectedItem)
            }
        }
    }
}

struct DetailView: View {
    let item: String

    var body: some View {
        VStack {
            Text("Detail for \(item)")
                .font(.title)
                .padding()

            List(0..<3) { index in
                DetailViewSubItem(item: "\(item) - SubItem \(index + 1)")
            }
            .frame(minWidth: 200)
        }
    }
}

struct DetailViewSubItem: View {
    let item: String
    @State private var showModal = false

    var body: some View {
        Button(action: {
            showModal = true
        }) {
            Text(item)
                .padding()
                .cornerRadius(8)
        }
        .padding()
        .sheet(isPresented: $showModal) {
            ModalView(text: item, showModal: $showModal)
        }
    }
}

struct ModalView: View {
    let text: String
    @Binding var showModal: Bool

    var body: some View {
        VStack {
            Text(text)
                .font(.title)
                .padding()

            Button(action: {
                dismissModal()
            }) {
                Text("Close")
                    .padding()
                    .cornerRadius(8)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.2))
    }

    func dismissModal() {
        showModal = false
    }
}

struct DataBrokerProfileQueryViewPreviews: PreviewProvider {
    static var previews: some View {
        DataBrokerProfileQueryView()
    }
}
