//
//  AutofillCredentialsDebugView.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import BrowserServicesKit
import Common
import SwiftUI

@available(macOS 13.5, *)
struct AutofillCredentialsDebugView: ModalView {

    @ObservedObject private var model: AutofillCredentialsDebugViewModel
    @State private var sortOrder = [KeyPathComparator(\AutofillCredentialsDebugViewModel.DisplayCredentials.accountId)]

    init(model: AutofillCredentialsDebugViewModel = AutofillCredentialsDebugViewModel()) {
        self.model = model
    }

    var body: some View {
        Table(model.credentials, sortOrder: $sortOrder) {
            TableColumn(Text(verbatim: "Id"), value: \.accountId) { selectableText($0.accountId) }
            TableColumn(Text(verbatim: "Website URL"), value: \.websiteUrl) { selectableText($0.websiteUrl) }
            TableColumn(Text(verbatim: "Domain"), value: \.domain) { selectableText($0.domain) }
            TableColumn(Text(verbatim: "Username"), value: \.username) { selectableText($0.username) }
            TableColumn(Text(verbatim: "Password"), value: \.displayPassword) { selectableText($0.displayPassword) }
            TableColumn(Text(verbatim: "Notes"), value: \.notes) { selectableText($0.notes) }
            TableColumn(Text(verbatim: "Created"), value: \.created) { selectableText($0.created) }
            TableColumn(Text(verbatim: "Last Updated"), value: \.lastUpdated) { selectableText($0.lastUpdated) }
            TableColumn(Text(verbatim: "Last Used"), value: \.lastUsed) { selectableText($0.lastUsed) }
            TableColumn(Text(verbatim: "Signature"), value: \.signature) { selectableText($0.signature) }
        }
        .onChange(of: sortOrder) { _ in
            applySort()
        }
    }

    private func selectableText(_ content: String) -> some View {
        Text(content)
            .textSelection(.enabled)
    }

    private func applySort() {
        model.credentials.sort(using: sortOrder)
    }
}

@available(macOS 13.5, *)
#Preview {
    AutofillCredentialsDebugView(model: AutofillCredentialsDebugViewModel())
}
