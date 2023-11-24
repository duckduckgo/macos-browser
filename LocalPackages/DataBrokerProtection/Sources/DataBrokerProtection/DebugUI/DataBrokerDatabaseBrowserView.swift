//
//  DataBrokerDataBaseBrowserView.swift
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

struct DataBrokerDatabaseBrowserView: View {
    @ObservedObject var viewModel: DataBrokerDatabaseBrowserViewModel

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.tables) { table in
                    NavigationLink(destination: DatabaseView(data: table.rows).navigationTitle(table.name),
                                   tag: table,
                                   selection: $viewModel.selectedTable) {
                        Text(table.name)
                    }
                }
            }
            .listStyle(.sidebar)

            if let table = viewModel.selectedTable {
                DatabaseView(data: table.rows)
                    .navigationTitle(table.name)
            } else {
                Text("No selection")
            }
        }
    }
}

struct DatabaseView: View {
    let data: [DataBrokerDatabaseBrowserData.Row]

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(data[0].data.keys.sorted(), id: \.self) { key in
                            VStack {
                                Text(key)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 35)
                                Divider()
                            }
                            if key != data[0].data.keys.sorted().last {
                                Divider()
                                    .background(Color.gray)
                            }
                        }
                    }
                    ForEach(data) { row in
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(row.data.keys.sorted(), id: \.self) { key in
                                VStack {
                                    Text("\(row.data[key]?.description ?? "")")
                                        .frame(maxWidth: .infinity, maxHeight: 50)
                                    Divider()
                                }
                                if key != row.data.keys.sorted().last {
                                    Divider()
                                        .background(Color.gray)
                                }
                            }
                        }
                    }
                    Spacer(minLength: geometry.size.height)
                }
                .frame(minWidth: geometry.size.width, minHeight: 0, alignment: .topLeading)
            }
        }
    }
}

struct ColumnData: Identifiable {
    var id = UUID()
    var columnName: String
    var items: [String]
}

//#Preview {
//    DataBrokerDatabaseBrowserView()
//}
