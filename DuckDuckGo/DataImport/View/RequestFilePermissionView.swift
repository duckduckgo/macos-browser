//
//  RequestFilePermissionView.swift
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

struct RequestFilePermissionView: View {

    private let source: DataImport.Source
    private let url: URL
    private let requestDataDirectoryPermission: @MainActor (URL) -> URL?
    private let callback: @MainActor (URL) -> Void

    init(source: DataImport.Source, url: URL, requestDataDirectoryPermission: @escaping @MainActor (URL) -> URL?, callback: @escaping @MainActor (URL) -> Void) {
        self.source = source
        self.url = url
        self.requestDataDirectoryPermission = requestDataDirectoryPermission
        self.callback = callback
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("DuckDuckGo needs your permission to read the \(source.importSourceName) bookmarks file. Select the \(source.importSourceName) folder to import bookmarks.",
                 comment: "Data import warning that DuckDuckGo browser requires file reading permissions for another browser name (%1$@), and instruction to select its (same browser name - %2$@) bookmarks folder.")
            Button("Select \(source.importSourceName) Folder…") {
                if let url = requestDataDirectoryPermission(url) {
                    callback(url)
                }
            }
        }
    }

}

#Preview {
    RequestFilePermissionView(source: .safari, url: URL(fileURLWithPath: "/file/path")) {
        $0
    } callback: { _ in }
        .padding(EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20))
        .frame(width: 512)
}
