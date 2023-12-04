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

    let model: DataImportSummaryViewModel

    init(_ importViewModel: DataImportViewModel, dataTypes: Set<DataType>? = nil) {
        self.init(model: .init(source: importViewModel.importSource, results: importViewModel.summary, dataTypes: dataTypes))
    }

    init(model: DataImportSummaryViewModel) {
        self.model = model
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            {
                switch model.summaryKind {
                case .results, .importComplete(.passwords):
                    Text("Import Results:", comment: "Data Import result summary headline")

                case .importComplete(.bookmarks),
                     .fileImportComplete(.bookmarks):
                    Text("Bookmarks Import Complete:", comment: "Bookmarks Data Import result summary headline")

                case .fileImportComplete(.passwords):
                    Text("Password import complete. You can now delete the saved passwords file.", comment: "message about Passwords Data Import completion")
                }
            }().padding(.bottom, 16)

            ForEach(model.results, id: \.dataType) { item in
                switch (item.dataType, item.result) {
                case (.bookmarks, .success(let summary)):
                    HStack {
                        successImage()
                        Text("Bookmarks: \(summary.successful)",
                             comment: "Data import summary format of how many bookmarks (%lld) were successfully imported.")
                    }
                    if summary.duplicate > 0 {
                        HStack {
                            failureImage()
                            Text("Duplicate Bookmarks Skipped: \(summary.duplicate)",
                                 comment: "Data import summary format of how many duplicate bookmarks (%lld) were skipped during import.")
                        }
                    }
                    if summary.failed > 0 {
                        HStack {
                            failureImage()
                            Text("Bookmark import failed: \(summary.failed)",
                                 comment: "Data import summary format of how many bookmarks (%lld) failed to import.")
                        }
                    }

                case (.bookmarks, .failure):
                    HStack {
                        failureImage()
                        Text("Bookmark import failed.",
                             comment: "Data import summary message of failed bookmarks import.")
                    }

                case (.passwords, .failure):
                    HStack {
                        failureImage()
                        Text("Passwords import failed.",
                             comment: "Data import summary message of failed passwords import.")
                    }

                case (.passwords, .success(let summary)):
                    HStack {
                        successImage()
                        Text("Passwords: \(summary.successful)",
                             comment: "Data import summary format of how many passwords (%lld) were successfully imported.")
                    }
                    if summary.failed > 0 {
                        HStack {
                            failureImage()
                            Text("Passwords import failed: \(summary.failed)",
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
    VStack {
        DataImportSummaryView(model: .init(source: .chrome, summary: [
            .bookmarks: .success(.init(successful: 123, duplicate: 456, failed: 7890)),
            .passwords: .success(.init(successful: 123, duplicate: 456, failed: 7890))
        ]))
        .padding(EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20))
    }
    .frame(width: 512)
}
