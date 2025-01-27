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
import BrowserServicesKit

struct DataImportSummaryView: View {

    typealias DataType = DataImport.DataType
    typealias Summary = DataImport.DataTypeSummary
    typealias DataTypeImportResult = DataImportViewModel.DataTypeImportResult

    let model: DataImportSummaryViewModel

    init(_ importViewModel: DataImportViewModel, dataTypes: Set<DataType>? = nil, isFileImport: Bool = false) {
        self.init(model: .init(source: importViewModel.importSource, isFileImport: isFileImport, results: importViewModel.summary, dataTypes: dataTypes))
    }

    init(model: DataImportSummaryViewModel) {
        self.model = model
    }

    private let zero = 0

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

            VStack {
                ForEach(model.resultsFiltered(by: .bookmarks), id: \.dataType) { item in
                    switch item.result {
                    case (.success(let summary)):
                        bookmarksSuccessSummary(summary)
                    case (.failure(let error)) where error.errorType == .noData:
                        importSummaryRow(image: .failed,
                                         text: "Bookmarks:",
                                         comment: "Data import summary format of how many bookmarks were successfully imported.",
                                         count: zero)
                    case (.failure):
                        importSummaryRow(image: .failed,
                                         text: "Bookmark import failed.",
                                         comment: "Data import summary message of failed bookmarks import.",
                                         count: nil)
                    }
                }
            }
            .applyConditionalModifiers(!model.resultsFiltered(by: .bookmarks).isEmpty)

            VStack {
                ForEach(model.resultsFiltered(by: .passwords), id: \.dataType) { item in
                    switch item.result {
                    case (.failure(let error)):
                        if error.errorType == .noData {
                            importSummaryRow(image: .failed,
                                             text: "Passwords:",
                                             comment: "Data import summary format of how many passwords were successfully imported.",
                                             count: zero)
                        } else {
                            importSummaryRow(image: .failed,
                                             text: "Password import failed.",
                                             comment: "Data import summary message of failed passwords import.",
                                             count: nil)
                        }

                    case (.success(let summary)):
                        passwordsSuccessSummary(summary)
                    }
                }
            }
            .applyConditionalModifiers(!model.resultsFiltered(by: .passwords).isEmpty)

            if !model.resultsFiltered(by: .passwords).isEmpty {
                importPasswordSubtitle()
            }
        }
    }
}

func bookmarksSuccessSummary(_ summary: DataImport.DataTypeSummary) -> some View {
    VStack {
        importSummaryRow(image: .success,
                         text: "Bookmarks:",
                         comment: "Data import summary format of how many bookmarks (%lld) were successfully imported.",
                         count: summary.successful)
        if summary.duplicate > 0 {
            lineSeparator()
            importSummaryRow(image: .failed,
                             text: "Duplicates Skipped:",
                             comment: "Data import summary format of how many duplicate bookmarks (%lld) were skipped during import.",
                             count: summary.duplicate)
        }
        if summary.failed > 0 {
            lineSeparator()
            importSummaryRow(image: .failed,
                             text: "Bookmark import failed:",
                             comment: "Data import summary format of how many bookmarks (%lld) failed to import.",
                             count: summary.failed)
        }
    }
}

private func passwordsSuccessSummary(_ summary: DataImport.DataTypeSummary) -> some View {
    VStack {
        importSummaryRow(image: .success,
                         text: "Passwords:",
                         comment: "Data import summary format of how many passwords (%lld) were successfully imported.",
                         count: summary.successful)
        if summary.failed > 0 {
            lineSeparator()
            importSummaryRow(image: .failed,
                             text: "Password import failed: ",
                             comment: "Data import summary format of how many passwords (%lld) failed to import.",
                             count: summary.failed)
        }
        if summary.duplicate > 0 {
            lineSeparator()
            importSummaryRow(image: .failed,
                             text: "Duplicates Skipped: ",
                             comment: "Data import summary format of how many passwords (%lld) were skipped due to being duplicates.",
                             count: summary.duplicate)
        }
    }
}

private func importPasswordSubtitle() -> some View {
    Text(UserText.importDataSubtitle)
        .font(.subheadline)
        .foregroundColor(Color(.greyText))
        .padding(.top, -2)
        .padding(.leading, 8)
}

private func importSummaryRow(image: Image, text: LocalizedStringKey, comment: StaticString, count: Int?) -> some View {
    HStack(spacing: 0) {
        image
            .frame(width: 16, height: 16)
            .padding(.trailing, 14)
        Text(text, comment: comment)
        Text(verbatim: " ")
        if let count = count {
            Text(String(count)).bold()
        }
        Spacer()
    }
}

private func lineSeparator() -> some View {
    Divider()
        .padding(EdgeInsets(top: 5, leading: 0, bottom: 8, trailing: 0))
}

private extension Image {
    static let success = Image(.successCheckmark)
    static let failed = Image(.clearRecolorable16)
}

private struct ConditionalModifier: ViewModifier {
    let applyModifiers: Bool

    func body(content: Content) -> some View {
        if applyModifiers {
            content
                .padding([.leading, .vertical])
                .padding(.trailing, 0)
                .roundedBorder()
        } else {
            content
        }
    }
}

private extension View {
    func applyConditionalModifiers(_ condition: Bool) -> some View {
        modifier(ConditionalModifier(applyModifiers: condition))
    }
}

#if DEBUG
#Preview {
    VStack {
        HStack {
            DataImportSummaryView(model: .init(source: .chrome, results: [
                .init(.bookmarks, .success(.init(successful: 123, duplicate: 456, failed: 7890))),
                //                .init(.passwords, .success(.init(successful: 123, duplicate: 456, failed: 7890))),
                //                .init(.bookmarks, .failure(DataImportViewModel.TestImportError(action: .bookmarks, errorType: .dataCorrupted))),
                //                .init(.bookmarks, .failure(DataImportViewModel.TestImportError(action: .passwords, errorType: .keychainError))),
                //                .init(.passwords, .failure(DataImportViewModel.TestImportError(action: .passwords, errorType: .keychainError))),
                //                .init(.passwords, .failure(DataImportViewModel.TestImportError(action: .passwords, errorType: .keychainError))),
                //                .init(.passwords, .success(.init(successful: 100, duplicate: 0, failed: 0)))
                    .init(.passwords, .success(.init(successful: 100, duplicate: 30, failed: 40)))
            ]))
            .padding(EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20))
            Spacer()
        }
    }
    .frame(width: 512, height: 400)
}
#endif
