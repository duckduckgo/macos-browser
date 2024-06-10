//
//  PrintSettingsViewModel.swift
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

import Foundation

final class PrintSettingsViewModel: NSObject, ObservableObject {

    private weak var printInfo: NSPrintInfo?

    @objc var shouldPrintBackgrounds: Bool {
        get {
            printInfo?.shouldPrintBackgrounds ?? false
        }
        set {
            guard let printInfo,
                  printInfo.shouldPrintBackgrounds != newValue else { return }

            objectWillChange.send()
            willChangeValue(forKey: #keyPath(shouldPrintBackgrounds))
            printInfo.shouldPrintBackgrounds = newValue
            NSPrintInfo.shared.shouldPrintBackgrounds = newValue
            didChangeValue(forKey: #keyPath(shouldPrintBackgrounds))
        }
    }

    @objc var shouldPrintHeadersAndFooters: Bool {
        get {
            printInfo?.shouldPrintHeadersAndFooters ?? false
        }
        set {
            guard let printInfo,
                  printInfo.shouldPrintHeadersAndFooters != newValue else { return }

            objectWillChange.send()
            willChangeValue(forKey: #keyPath(shouldPrintHeadersAndFooters))
            printInfo.shouldPrintHeadersAndFooters = newValue
            NSPrintInfo.shared.shouldPrintHeadersAndFooters = newValue
            didChangeValue(forKey: #keyPath(shouldPrintHeadersAndFooters))
        }
    }

    init(printInfo: NSPrintInfo) {
        self.printInfo = printInfo
        super.init()
    }

}
