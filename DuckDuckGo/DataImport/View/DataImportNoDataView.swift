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
import BrowserServicesKit

struct DataImportNoDataView: View {

    let source: DataImport.Source
    let dataType: DataImport.DataType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch dataType {
            case .bookmarks:
                Text("We couldn‘t find any bookmarks.", comment: "Data import error message: Bookmarks weren‘t found.")
                    .bold()

                Text(UserText.importNoDataBookmarksSubtitle(from: source))

            case .passwords:
                Text("We couldn‘t find any passwords.", comment: "Data import error message: Passwords weren‘t found.")
                    .bold()

                Text(UserText.importNoDataPasswordsSubtitle(from: source))
            }
        }
    }

}

#Preview {
    DataImportNoDataView(source: .chrome, dataType: .bookmarks)
        .frame(width: 512 - 20)
        .padding()
}
