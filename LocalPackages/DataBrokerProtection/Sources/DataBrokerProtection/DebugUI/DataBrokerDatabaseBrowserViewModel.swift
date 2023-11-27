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
import SecureStorage

final class DataBrokerDatabaseBrowserViewModel: ObservableObject {
    @Published var selectedTable: DataBrokerDatabaseBrowserData.Table?
    var tables: [DataBrokerDatabaseBrowserData.Table]
    private let vault: DatabaseDebugSecureVault<DefaultDataBrokerProtectionDatabaseProvider>?

    internal init(tables: [DataBrokerDatabaseBrowserData.Table]? = nil) {

        if let tables = tables {
            self.tables = tables
            self.vault = nil
            self.selectedTable = tables.first
        } else {
            self.vault = try? DebugSecureVaultFactory.makeVault(errorReporter: nil)
            self.tables = [DataBrokerDatabaseBrowserData.Table]()
            updateTables()
        }
    }

    private func createTable(using fetchData: () -> [Any], tableName: String) -> DataBrokerDatabaseBrowserData.Table {
        let rows = fetchData().map { convertToGenericRowData($0) }
        let table = DataBrokerDatabaseBrowserData.Table(name: tableName, rows: rows)
        return table
    }

    private func updateTables() {
        guard let vault = self.vault else { return }

        let scanTable = createTable(using: vault.fetchAllScans, tableName: "Scans")
        let brokerTable = createTable(using: vault.fetchAllBrokers, tableName: "Brokers")
        let optOutTable = createTable(using: vault.fetchAllOptOuts, tableName: "OptOut")
        let extractedProfile = createTable(using: vault.fetchAllExtractedProfiles, tableName: "ExtractedProfile")
        let scanHistory = createTable(using: vault.fetchAllScanHistoryEvents, tableName: "ScanHistory")
        let optOutHistory = createTable(using: vault.fetchAllOptOutHistoryEvents, tableName: "OptOutHistory")

        self.tables = [scanTable, brokerTable, optOutTable, extractedProfile, scanHistory, optOutHistory]
    }

    private func convertToGenericRowData<T>(_ item: T) -> DataBrokerDatabaseBrowserData.Row {
        let mirror = Mirror(reflecting: item)
        var data: [String: CustomStringConvertible] = [:]
        for child in mirror.children {
            var label: String
            var value: CustomStringConvertible

            if let childLabel = child.label {
                label = childLabel
            } else {
                label = "No label"
            }

            if let childValue = child.value as? CustomStringConvertible {
                value = childValue
            } else {
                value = "No value"
            }
            data[label] = value
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
