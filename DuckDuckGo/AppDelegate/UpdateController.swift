//
//  UpdateController.swift
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
import Sparkle

#if OUT_OF_APPSTORE
final class UpdateController: NSObject {

    private let updater = SUUpdater()

    override init() {
        super.init()

        configureUpdater()
    }

    func checkForUpdates(_ sender: Any!) {
        updater.checkForUpdates(sender)
    }

    private func configureUpdater() {
    // The default configuration of Sparkle updates is in Info.plist

#if DEBUG
        updater.automaticallyChecksForUpdates = false
        updater.updateCheckInterval = 0
#endif
    }

}
#endif
