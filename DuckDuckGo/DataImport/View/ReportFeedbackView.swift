//
//  ReportFeedbackView.swift
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

struct ReportFeedbackView: View {

    @Binding var model: DataImportReportModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            {
                if model.retryNumber <= 1 {
                    Text("Please submit a report to help us fix the issue.",
                         comment: "Data import failure Report dialog title.")
                } else {
                    Text("That didn’t work either. Please submit a report to help us fix the issue.",
                         comment: "Data import failure Report dialog title containing a message that not only automatic data import has failed failed but manual browser data import didn‘t work either.")
                }
            }()
                .bold()
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 12) {
                Text("""
                The following information will be sent to DuckDuckGo. No personally identifiable information will be sent.
                """, comment: "Data import failure Report dialog subtitle about the data being collected with the report.")

                InfoItemView(model.osVersion) {
                    Text("macOS version", comment: "Data import failure Report dialog description of a report field providing user‘s macOS version")
                }
                InfoItemView(model.appVersion) {
                    Text("DuckDuckGo browser version", comment: "Data import failure Report dialog description of a report field providing current DuckDuckGo Browser version")
                }
                InfoItemView(model.importSourceDescription) {
                    Text("The version of the browser you are trying to import from", comment: "Data import failure Report dialog description of a report field providing version of a browser user is trying to import data from")
                }
                InfoItemView(model.error.localizedDescription) {
                    Text("Error message & code", comment: "Title of the section of a dialog (form where the user can report feedback) where the error message and the error code are shown")
                }
            }
            .padding(.bottom, 24)

            EditableTextView(text: $model.text,
                             font: .systemFont(ofSize: 13),
                             insets: NSSize(width: 7, height: 12),
                             cornerRadius: 6,
                             backgroundColor: .textBackgroundColor,
                             textColor: .textColor,
                             focusRingType: .exterior,
                             isFocusedOnAppear: true)
            .frame(height: 114)
            .shadow(color: Color.addressBarShadow, radius: 1, x: 0, y: 1)
            .overlay(
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        Text("Add any details that you think may help us fix the problem",
                             comment: "Data import failure Report dialog suggestion to provide a comments with extra details helping to identify the data import problem.")
                        .foregroundColor(Color(.placeholderTextColor))
                        .padding(.leading, 11)
                        Spacer()
                    }
                    .padding(.top, 11)
                    Spacer()
                }
                    .visibility(model.text.isEmpty ? .visible : .gone)
                    .allowsHitTesting(false)
            )
        }
    }

}

private struct InfoItemView: View {

    let text: () -> Text
    let data: String
    @State private var isPopoverVisible = false

    init(_ data: String, text: @escaping () -> Text) {
        self.text = text
        self.data = data
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isPopoverVisible.toggle()
            } label: {
                Image(.infoLight)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $isPopoverVisible, arrowEdge: .bottom) {
                Text(data).padding()
            }

            text()
        }
    }

}

#if DEBUG
extension InfoItemView {
    struct PreviewView: View {
        @State var model = DataImportReportModel(importSource: .safari, importSourceVersion: UserAgent.safariVersion, error: {
            enum ImportError: DataImportError {
                enum OperationType: Int {
                    case imp
                }

                var type: OperationType { .imp }
                var action: DataImportAction { .generic }
                var underlyingError: Error? {
                    if case .err(let err) = self {
                        return err
                    }
                    return nil
                }

                static var errorDomain: String { "ReportFeedbackPreviewError" }
                var errorType: DataImport.ErrorType { .noData }

                case err(Error)
            }
            return ImportError.err(CocoaError(.fileReadUnknown))
        }(), retryNumber: 1)

        var body: some View {
            ReportFeedbackView(model: $model)
                .frame(width: 512 - 20)
                .padding(EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20))
        }
    }
}

#Preview {
    InfoItemView.PreviewView()
}
#endif
