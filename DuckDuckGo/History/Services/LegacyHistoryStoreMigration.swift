//
//  LegacyHistoryStoreMigration.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
import History
import Persistence
import PixelKit

public class LegacyHistoryStoreMigration {

    // swiftlint:disable:next cyclomatic_complexity
    public static func setupAndMigrate(from source: NSManagedObjectContext,
                                       to destination: NSManagedObjectContext) {

        do {
            // Fetch all history entries from source
            try migrateHistoryEntries(from: source, to: destination)
            cleanupOldData(in: source)
        } catch {
            fatalError("Could not write to History DB")
        }
    }

    private static func migrateHistoryEntries(from source: NSManagedObjectContext, to destination: NSManagedObjectContext) throws { // [HistoryEntryManagedObject] {
        let batchSize = 100

        let fetchRequest = HistoryEntryManagedObject.fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.relationshipKeyPathsForPrefetching = [#keyPath(HistoryEntryManagedObject.visits)]
        fetchRequest.fetchLimit = batchSize
        fetchRequest.fetchOffset = 0

        repeat {
            let entries = try source.fetch(fetchRequest)
            guard !entries.isEmpty else {
                break
            }

            for entry in entries {
                let browsingHistoryEntry = BrowsingHistoryEntryManagedObject(context: destination)
                browsingHistoryEntry.update(with: entry, in: destination)
            }
            try destination.save(onErrorFire: GeneralPixel.historyMigrationFailed)
            source.reset()
            fetchRequest.fetchOffset += batchSize
        } while true
    }

    private static func cleanupOldData(in context: NSManagedObjectContext) {
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: HistoryEntryManagedObject.fetchRequest())
        do {
            try context.execute(deleteRequest)
            context.reset()
        } catch {
            let nsError = error as NSError
            let processedErrors = CoreDataErrorsParser.parse(error: nsError)

            PixelKit.fire(
                DebugEvent(GeneralPixel.historyMigrationFailed, error: error),
                withAdditionalParameters: processedErrors.errorPixelParameters
            )
        }
    }
}

private extension BrowsingHistoryEntryManagedObject {

    func update(with historyEntryMO: HistoryEntryManagedObject, in context: NSManagedObjectContext) {
        self.blockedTrackingEntities = historyEntryMO.blockedTrackingEntities
        self.failedToLoad = historyEntryMO.failedToLoad
        self.identifier = historyEntryMO.identifier
        self.lastVisit = historyEntryMO.lastVisit
        self.numberOfTotalVisits = historyEntryMO.numberOfTotalVisits
        self.numberOfTrackersBlocked = historyEntryMO.numberOfTrackersBlocked
        self.title = historyEntryMO.titleEncrypted as? String
        self.trackersFound = historyEntryMO.trackersFound
        self.url = historyEntryMO.urlEncrypted as? URL

        guard let visits = historyEntryMO.visits as? Set<VisitManagedObject> else {
            return
        }
        for visit in visits {
            let pageVisit = PageVisitManagedObject(context: context)
            pageVisit.date = visit.date
            self.addToVisits(pageVisit)
        }
    }
}
