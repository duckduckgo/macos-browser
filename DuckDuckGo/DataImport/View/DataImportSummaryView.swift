//
//  DataImportSummaryView.swift
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

struct DataImportSummaryView: View {

    typealias DataType = DataImport.DataType
    typealias Summary = DataImport.DataTypeSummary

    let summary: [DataType: Summary]

    init(summary: [DataType: Summary]) {
        self.summary = summary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(DataType.allCases.compactMap {
                guard let result = summary[$0] else { return nil }
                return (dataType: $0, result: result)
            }, id: \.dataType) { (item: (dataType: DataType, result: Summary)) in
                switch item.dataType {
                case .bookmarks:
                    HStack {
                        successImage()
                        Text("Bookmarks: \(item.result.successful)",
                             comment: "Data import summary format of how many bookmarks (%lld) were successfully imported.")
                    }
                    if item.result.duplicate > 0 {
                        HStack {
                            failureImage()
                            Text("Duplicate Bookmarks Skipped: \(item.result.duplicate)",
                                 comment: "Data import summary format of how many duplicate bookmarks (%lld) were skipped during import.")
                        }
                    }
                    if item.result.failed > 0 {
                        HStack {
                            failureImage()
                            Text("Bookmark import failed: \(item.result.failed)",
                                 comment: "Data import summary format of how many bookmarks (%lld) failed to import.")
                        }
                    }

                case .passwords:
                    HStack {
                        successImage()
                        Text("Passwords: \(item.result.successful)",
                             comment: "Data import summary format of how many passwords (%lld) were successfully imported.")
                    }
                    if item.result.failed > 0 {
                        HStack {
                            failureImage()
                            Text("Passwords import failed: \(item.result.failed)",
                                 comment: "Data import summary format of how many passwords (%lld) failed to import.")
                        }
                    }
                }
            }
        }
    }

}

private func successImage() -> some View {
    Image(.successCheckmark)
        .frame(width: 16, height: 16)
}

private func failureImage() -> some View {
    Image(.error)
        .frame(width: 16, height: 16)
}

#Preview {
    DataImportSummaryView(summary: [
        .bookmarks: .init(successful: 123, duplicate: 456, failed: 7890),
        .passwords: .init(successful: 123, duplicate: 456, failed: 7890)
    ])
    .padding(EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20))
    .frame(width: 512)
}
