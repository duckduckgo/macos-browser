//
//  DataBrokerDatabaseBrowserViewModel.swift
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

import Foundation

final class DataBrokerDatabaseBrowserViewModel: ObservableObject {
    @Published var selectedTable: DataBrokerDatabaseBrowserData.Table?
    let tables: [DataBrokerDatabaseBrowserData.Table]

    internal init(tables: [DataBrokerDatabaseBrowserData.Table]) {
        self.tables = tables
    }

    private func convertToGenericRowData<T>(_ item: T) -> DataBrokerDatabaseBrowserData.Row {
        let mirror = Mirror(reflecting: item)
        var data: [String: CustomStringConvertible] = [:]
        for child in mirror.children {
            if let label = child.label, let value = child.value as? CustomStringConvertible {
                data[label] = value
            }
        }
        return DataBrokerDatabaseBrowserData.Row(data: data)
    }
}

struct DataBrokerDatabaseBrowserData {

    struct Row: Identifiable, Hashable {
        var id = UUID()
        var data: [String: CustomStringConvertible]

        static func == (lhs: Row, rhs: Row) -> Bool {
            return lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    struct Table: Hashable, Identifiable {
        let id = UUID()
        let name: String
        let rows: [DataBrokerDatabaseBrowserData.Row]

        static func == (lhs: Table, rhs: Table) -> Bool {
            return lhs.name == rhs.name
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
        }
    }

}
