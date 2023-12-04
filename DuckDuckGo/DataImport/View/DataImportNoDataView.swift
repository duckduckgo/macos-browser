//
//  DataImportNoDataView.swift
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

struct DataImportNoDataView: View {

    let source: DataImport.Source
    let dataType: DataImport.DataType
    let manualImportAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("We couldn‘t find any \(dataType.displayName)…", comment: "Data import error message: Bookmarks or Passwords (%@) weren‘t found.")

            Text("You could try importing \(dataType.displayName) manually.",
                 comment: "Data import error subtitle: suggestion to import Bookmarks or Passwords (%@) manually by selecting a CSV or HTML file.")

            Button(UserText.manualImport, action: manualImportAction)
        }
    }

}

#Preview {
    DataImportNoDataView(source: .chrome, dataType: .bookmarks) { print("Manual Import") }
        .frame(width: 512 - 20)
        .padding()
}
