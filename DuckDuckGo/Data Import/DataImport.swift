//
//  DataImport.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

enum DataImport {

    enum Source: CaseIterable {
        case brave
        case chrome
        case edge
        case firefox
        case csv

        var importSourceName: String {
            switch self {
            case .brave:
                return "Brave"
            case .chrome:
                return "Chrome"
            case .edge:
                return "Edge"
            case .firefox:
                return "Firefox"
            case .csv:
                return UserText.importLoginsCSV
            }
        }

        var importSourceImage: NSImage? {
            return ThirdPartyBrowser.browser(for: self)?.applicationIcon
        }

        var canImportData: Bool {
            return ThirdPartyBrowser.browser(for: self)?.isInstalled ?? true
        }

        var showSuccessScreen: Bool {
            switch self {
            case .csv: return true
            default: return false
            }
        }
    }

    // Different data types (e.g. bookmarks) will be added later.
    enum DataType {
        case logins
    }

    enum Summary: Equatable {
        case logins(successfulImports: [String], duplicateImports: [String], failedImports: [String])
    }

}

enum DataImportError: Error {

    case cannotReadFile
    case browserNeedsToBeClosed
    case cannotAccessSecureVault

}

/// Represents an object able to import data from an outside source. The outside source may be capable of importing multiple types of data.
/// For instance, a browser data importer may be able to import logins and bookmarks.
protocol DataImporter {

    /// Performs a quick check to determine if the data is able to be imported. It does not guarantee that the import will succeed.
    /// For example, a CSV importer will return true if the URL it has been created with is a CSV file, but does not check whether the CSV data matches the expected format.
    func importableTypes() -> [DataImport.DataType]

    func importData(types: [DataImport.DataType], completion: @escaping (Result<[DataImport.Summary], DataImportError>) -> Void)

}
