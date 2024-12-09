//
//  Update.swift
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

#if SPARKLE
import Foundation
import Sparkle

final class Update {

    enum UpdateType {
        case regular
        case critical
    }

    let isInstalled: Bool
    let type: UpdateType
    let version: String
    let build: String
    let date: Date
    let releaseNotes: [String]
    let releaseNotesPrivacyPro: [String]
    let needsLatestReleaseNote: Bool

    var title: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd yyyy"
        return formatter.string(from: date)
    }

    internal init(isInstalled: Bool,
                  type: Update.UpdateType,
                  version: String,
                  build: String,
                  date: Date,
                  releaseNotes: [String],
                  releaseNotesPrivacyPro: [String],
                  needsLatestReleaseNote: Bool) {
        self.isInstalled = isInstalled
        self.type = type
        self.version = version
        self.build = build
        self.date = date
        self.releaseNotes = releaseNotes
        self.releaseNotesPrivacyPro = releaseNotesPrivacyPro
        self.needsLatestReleaseNote = needsLatestReleaseNote
    }

}

extension Update {
    convenience init(appcastItem: SUAppcastItem, isInstalled: Bool, needsLatestReleaseNote: Bool) {
        let isCritical = appcastItem.isCriticalUpdate
        let version = appcastItem.displayVersionString
        let build = appcastItem.versionString
        let date = appcastItem.date ?? Date()
        let (releaseNotes, releaseNotesPrivacyPro) = ReleaseNotesParser.parseReleaseNotes(from: appcastItem.itemDescription)

        self.init(isInstalled: isInstalled,
                  type: isCritical ? .critical : .regular,
                  version: version,
                  build: build,
                  date: date,
                  releaseNotes: releaseNotes,
                  releaseNotesPrivacyPro: releaseNotesPrivacyPro,
                  needsLatestReleaseNote: needsLatestReleaseNote)
    }
}

#endif
