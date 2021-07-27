//
//  ChromiumDataImporter.swift
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

internal class ChromiumDataImporter: DataImporter {

    var processName: String {
        fatalError("Subclasses must provide their own process name")
    }

    private let applicationDataDirectoryPath: String
    private let loginImporter: LoginImporter

    init(applicationDataDirectoryPath: String, loginImporter: LoginImporter) {
        self.applicationDataDirectoryPath = applicationDataDirectoryPath
        self.loginImporter = loginImporter
    }

    func importableTypes() -> [DataImport.DataType] {
        // TODO: Check if browser data exists at the application directory path
        return [.logins]
    }

    func importData(types: [DataImport.DataType], completion: @escaping (Result<[DataImport.Summary], DataImportError>) -> Void) {
        print("Data Import (Chromium): Beginning import...")

        let loginReader = ChromiumLoginReader(chromiumDataDirectoryPath: applicationDataDirectoryPath, processName: processName)
        let loginResult = loginReader.readLogins()

        switch loginResult {
        case .success(let logins):
            do {
                let summary = try loginImporter.importLogins(logins)
                print("Data Import (Chromium): Success! \(summary)")
                completion(.success([summary]))
            } catch {
                print("Data Import (Chromium): Cannot access vault")
                completion(.failure(.cannotAccessSecureVault))
            }
        case .failure:
            print("Data Import (Chromium): Cannot read database")
            completion(.failure(.cannotReadFile))
        }

        completion(.success([]))
    }

}
