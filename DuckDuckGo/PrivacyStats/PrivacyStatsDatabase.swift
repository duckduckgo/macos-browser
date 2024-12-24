//
//  PrivacyStatsDatabase.swift
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
import CoreData
import PixelKit
import PrivacyStats
import Persistence

public final class PrivacyStatsDatabase: PrivacyStatsDatabaseProviding {

    public let db: CoreDataDatabase

    init(db: CoreDataDatabase = make(location: URL.sandboxApplicationSupportURL)) {
        self.db = db
    }

    public static func make(location: URL) -> CoreDataDatabase {
        let bundle = PrivacyStats.bundle
        guard let model = CoreDataDatabase.loadModel(from: bundle, named: "PrivacyStats") else {
            fatalError("Failed to load model")
        }
        return CoreDataDatabase(name: "PrivacyStats", containerLocation: location, model: model)
    }

    public func initializeDatabase() -> CoreDataDatabase {
        if NSApplication.runType.requiresEnvironment {
            db.loadStore { context, error in
                guard context != nil else {
                    if let error = error {
                        PixelKit.fire(DebugEvent(NewTabPagePixel.privacyStatsCouldNotLoadDatabase, error: error), frequency: .dailyAndCount)
                    } else {
                        PixelKit.fire(DebugEvent(NewTabPagePixel.privacyStatsCouldNotLoadDatabase), frequency: .dailyAndCount)
                    }

                    Thread.sleep(forTimeInterval: 1)
                    fatalError("Could not create Privacy Stats database stack: \(error?.localizedDescription ?? "err")")
                }
            }
        }
        return db
    }
}
