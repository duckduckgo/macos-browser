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

    init(_ importViewModel: DataImportViewModel, dataTypes: Set<DataType>? = nil, isFileImport: Bool = false) {
        self.init(model: .init(source: importViewModel.importSource, isFileImport: isFileImport, results: importViewModel.summary, dataTypes: dataTypes))
    }

    init(model: DataImportSummaryViewModel) {
        self.model = model
    }

    private let zeroString = "0"

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
            }().padding(.bottom, 4)

            ForEach(model.results, id: \.dataType) { item in
                switch (item.dataType, item.result) {
                case (.bookmarks, .success(let summary)):
                    HStack {
                        successImage()
                        Text("Bookmarks:",
                             comment: "Data import summary format of how many bookmarks (%lld) were successfully imported.")
                        + Text(" " as String)
                        + Text(String(summary.successful)).bold()
                    }
                    if summary.duplicate > 0 {
                        HStack {
                            skippedImage()
                            Text("Duplicate Bookmarks Skipped:",
                                 comment: "Data import summary format of how many duplicate bookmarks (%lld) were skipped during import.")
                            + Text(" " as String)
                            + Text(String(summary.duplicate)).bold()
                        }
                    }
                    if summary.failed > 0 {
                        HStack {
                            failureImage()
                            Text("Bookmark import failed:",
                                 comment: "Data import summary format of how many bookmarks (%lld) failed to import.")
                            + Text(" " as String)
                            + Text(String(summary.failed)).bold()
                        }
                    }

                case (.bookmarks, .failure(let error)) where error.errorType == .noData:
                    HStack {
                        skippedImage()
                        Text("Bookmarks:",
                             comment: "Data import summary format of how many bookmarks were successfully imported.")
                        + Text(" " as String)
                        + Text(zeroString).bold()
                    }

                case (.bookmarks, .failure):
                    HStack {
                        failureImage()
                        Text("Bookmark import failed.",
                             comment: "Data import summary message of failed bookmarks import.")
                    }

                case (.passwords, .failure(let error)):
                    if error.errorType == .noData {
                        HStack {
                            skippedImage()
                            Text("Passwords:",
                                 comment: "Data import summary format of how many passwords were successfully imported.")
                            + Text(" " as String)
                            + Text(zeroString).bold()
                        }
                    } else {
                        HStack {
                            failureImage()
                            Text("Password import failed.",
                                 comment: "Data import summary message of failed passwords import.")
                        }
                    }

                case (.passwords, .success(let summary)):
                    HStack {
                        successImage()
                        Text("Passwords:",
                             comment: "Data import summary format of how many passwords (%lld) were successfully imported.")
                        + Text(" " as String)
                        + Text(String(summary.successful)).bold()
                    }
                    if summary.failed > 0 {
                        HStack {
                            failureImage()
                            Text("Password import failed: ",
                                 comment: "Data import summary format of how many passwords (%lld) failed to import.")
                            + Text(" " as String)
                            + Text(String(summary.failed)).bold()
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

private func skippedImage() -> some View {
    Image(.skipped)
        .frame(width: 16, height: 16)
}

#if DEBUG
#Preview {
    VStack {
        HStack {
            DataImportSummaryView(model: .init(source: .chrome, results: [
//                .init(.bookmarks, .success(.init(successful: 123, duplicate: 456, failed: 7890))),
//                .init(.passwords, .success(.init(successful: 123, duplicate: 456, failed: 7890))),
//                .init(.bookmarks, .failure(DataImportViewModel.TestImportError(action: .bookmarks, errorType: .dataCorrupted))),
//                .init(.bookmarks, .failure(DataImportViewModel.TestImportError(action: .passwords, errorType: .keychainError))),
                .init(.passwords, .failure(DataImportViewModel.TestImportError(action: .passwords, errorType: .keychainError))),
                .init(.passwords, .failure(DataImportViewModel.TestImportError(action: .passwords, errorType: .keychainError))),
            ]))
            .padding(EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20))
            Spacer()
        }
    }
    .frame(width: 512)
}
#endif
