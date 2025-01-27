//
//  BrowserImportMoreInfoView.swift
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

struct BrowserImportMoreInfoView: View {

    private let source: DataImport.Source

    init(source: DataImport.Source) {
        self.source = source
    }

    var body: some View {
        switch source {
        case .chrome, .chromium, .coccoc, .edge, .brave, .opera, .operaGX, .vivaldi:
            Text("""
            After clicking import, your computer may ask you to enter a password. You may need to enter your password two times before importing starts. DuckDuckGo will not see that password.

            Imported passwords are stored securely using encryption.
            """, comment: "Warning that Chromium data import would require entering system passwords.")

        case .firefox:
            Text("""
            You'll be asked to enter your Primary Password for \(source.importSourceName).

            Imported passwords are encrypted and only stored on this computer.
            """, comment: "Warning that Firefox-based browser name (%@) data import would require entering a Primary Password for the browser.")

        case .safari, .safariTechnologyPreview, .yandex, .csv, .bitwarden, .lastPass, .onePassword7, .onePassword8, .bookmarksHTML, .tor:
            fatalError("Unsupported source for more info")
        }
    }

}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        BrowserImportMoreInfoView(source: .chrome)

        Divider()

        BrowserImportMoreInfoView(source: .firefox)
    }
    .padding(EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20))
    .frame(width: 512)
}
