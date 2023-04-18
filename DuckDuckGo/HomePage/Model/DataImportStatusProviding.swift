//
//  DataImportProvider.swift
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

import Foundation
import Bookmarks
import BrowserServicesKit

protocol DataImportStatusProviding {
    var didImport: Bool { get }
    func showImportWindow(completion: (() -> Void)?)
}

final class BookmarksAndPasswordsImportStatusProvider: DataImportStatusProviding {

    let secureVault: SecureVault?
    let bookmarkManager: BookmarkManager

    init(secureVault: SecureVault? = try? SecureVaultFactory.default.makeVault(errorReporter: SecureVaultErrorReporter.shared),
         bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.secureVault = secureVault
        self.bookmarkManager = bookmarkManager
    }

    @UserDefaultsWrapper(key: .homePageContinueSetUpImport, defaultValue: nil)
    private var successfulImportHappened: Bool?

    // The successfulImportHappened boolean covers only users who start importing after this code is live.
    // To cover as much as possible users that have imported data in the past we try some hack to detect if they have imported bookmarks or passwords
    var didImport: Bool {
        if successfulImportHappened == nil {
            successfulImportHappened = didImportBookarks || didImportPasswords
        }
        return successfulImportHappened!
    }
    func showImportWindow(completion: (() -> Void)?) {
        DataImportViewController.show(completion: completion)
    }

    // It only cover the case in which the user has imported bookmar AFTER already having some bookmarks
    // There is no way to detect whether the user has imported bookmarks as first thing
    private var didImportBookarks: Bool {
        guard let folders = bookmarkManager.list?.topLevelEntities else { return false }
        for folder in folders.reversed() where folder.title.contains(UserText.bookmarkImportedFromFolder) {
            return true
        }
        return false
    }

    // Checks if there are multiple passwords created at the same time which would indicate that they were created through import
    private var didImportPasswords: Bool {
        guard let secureVault else {
            return false
        }

        var dates: [Date] = []
        if let accountsDates = try? secureVault.accounts().map({ $0.created }) {
            dates.append(contentsOf: accountsDates)
        }
        if let noteDates = try? secureVault.notes().map({ $0.created }) {
            dates.append(contentsOf: noteDates)
        }
        if let cardDates = try? secureVault.creditCards().map({ $0.created }) {
            dates.append(contentsOf: cardDates)
        }
        if let identitiesDates = try? secureVault.identities().map({ $0.created }) {
            dates.append(contentsOf: identitiesDates)
        }
        guard dates.count >= 2 else {
            return false
        }

        let sortedDates = dates.sorted()
        for ind in 1..<sortedDates.count {
            let sameSecond = Calendar.current.isDate(sortedDates[ind], equalTo: sortedDates[ind - 1], toGranularity: .second)
            if sameSecond {
                return true
            }
        }
        return false
    }

}
