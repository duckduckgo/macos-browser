//
//  DataImportErrorView.swift
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
import SwiftUI
import BrowserServicesKit

struct DataImportErrorView: View {

    let source: DataImport.Source
    let dataType: DataImport.DataType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch dataType {
            case .bookmarks:
                Text("We were unable to import bookmarks directly from \(source.importSourceName).",
                     comment: "Message when data import fails from a browser. %@ - a browser name")
                .bold()
            case .passwords:
                Text("We were unable to import passwords directly from \(source.importSourceName).",
                     comment: "Message when data import fails from a browser. %@ - a browser name")
                .bold()
            }

            Text("Let’s try doing it manually. It won’t take long.",
                 comment: "Suggestion to switch to a Manual File Data Import when data import fails.")
        }
    }

}

#Preview {
    DataImportNoDataView(source: .chrome, dataType: .bookmarks)
        .frame(width: 512 - 20)
        .padding()
}
