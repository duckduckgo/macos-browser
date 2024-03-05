//
//  DataBrokerDatabaseBrowserView.swift
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
        .frame(minWidth: 1300, minHeight: 800)
    }
}

struct DatabaseView: View {
    @State private var isPopoverVisible = false
    @State private var selectedData: String = ""
    let data: [DataBrokerDatabaseBrowserData.Row]
    let rowHeight: CGFloat = 40.0

    var body: some View {
        if data.count > 0 {
            VStack {
                dataView()
                TextEditor(text: $selectedData)
                    .frame(height: 100)
            }
        } else {
            Text("No Data")
        }
    }

    private func spacerHeight(_ geometry: GeometryProxy) -> CGFloat {
        let result = geometry.size.height - CGFloat(data.count) * rowHeight
        return max(0, result)
    }

    private func dataView() -> some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(data[0].data.keys.sorted(), id: \.self) { key in
                            VStack {
                                Text(key)
                                    .font(.headline)
                                    .frame(maxWidth: 200)
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
                                        .frame(maxWidth: 200)
                                        .frame(height: rowHeight)
                                        .frame(minWidth: 60)
                                        .onTapGesture {
                                            selectedData = row.data[key]?.description ?? ""
                                        }
                                    Divider()
                                }
                                if key != row.data.keys.sorted().last {
                                    Divider()
                                        .background(Color.gray)
                                }
                            }
                        }
                    }
                    Spacer()
                        .frame(height: spacerHeight(geometry))
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

#Preview {
    let fakeRows1 = (1...10).map { index in
        DataBrokerDatabaseBrowserData.Row(data: ["Name": "John Doe", "Age": Int.random(in: 20...60), "Email": "john.doe\(index)@example.com"])
    }
    let fakeTable1 = DataBrokerDatabaseBrowserData.Table(name: "Users", rows: fakeRows1)

    let fakeRows2 = (1...10).map { index in
        DataBrokerDatabaseBrowserData.Row(data: ["Product": "Product \(index)", "Price": Double.random(in: 10...100), "Quantity": Int.random(in: 1...10)])
    }
    let fakeTable2 = DataBrokerDatabaseBrowserData.Table(name: "Products", rows: fakeRows2)

    let fakeTables =  [fakeTable1, fakeTable2]

    return DataBrokerDatabaseBrowserView(viewModel: DataBrokerDatabaseBrowserViewModel(tables: fakeTables))
}
