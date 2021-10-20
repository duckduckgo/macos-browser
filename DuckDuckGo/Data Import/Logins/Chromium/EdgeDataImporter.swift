//
//  EdgeDataImporter.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

final class EdgeDataImporter: ChromiumDataImporter {

    override var processName: String {
        return "Microsoft Edge"
    }

    init(loginImporter: LoginImporter, bookmarkImporter: BookmarkImporter) {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let path = applicationSupport.appendingPathComponent("Microsoft Edge/Default/").absoluteString

        super.init(applicationDataDirectoryPath: path, loginImporter: loginImporter, bookmarkImporter: bookmarkImporter)
    }

}
