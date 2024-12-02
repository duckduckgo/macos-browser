//
//  EncryptedHistoryStore.swift
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

import Common
import Foundation
import CoreData
import Combine
import History
import PixelKit
import os.log

final class EncryptedHistoryStore: HistoryStoring {

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    enum HistoryStoreError: Error {
        case storeDeallocated
        case savingFailed
    }

    let context: NSManagedObjectContext

    func removeEntries(_ entries: [HistoryEntry]) -> Future<Void, Error> {
        return Future { [weak self] promise in
            self?.context.perform {
                guard let self = self else {
                    promise(.failure(HistoryStoreError.storeDeallocated))
                    return
                }

                let identifiers = entries.map { $0.identifier }
                switch self.remove(identifiers, context: self.context) {
                case .failure(let error):
                    self.context.reset()
                    promise(.failure(error))
                case .success:
                    promise(.success(()))
                }
            }
        }
    }

    func cleanOld(until date: Date) -> Future<BrowsingHistory, Error> {
        return Future { [weak self] promise in
            self?.context.perform {
                guard let self = self else {
                    promise(.failure(HistoryStoreError.storeDeallocated))
                    return
                }

                switch self.clean(self.context, until: date) {
                case .failure(let error):
                    self.context.reset()
                    promise(.failure(error))
                case .success:
                    let reloadResult = self.reload(self.context)
                    promise(reloadResult)
                }
            }
        }
    }

    private func remove(_ identifiers: [UUID], context: NSManagedObjectContext) -> Result<Void, Error> {
        // To avoid long predicate, execute multiple times
        let chunkedIdentifiers = identifiers.chunked(into: 100)

        for identifiers in chunkedIdentifiers {
            let deleteRequest = NSFetchRequest<HistoryEntryManagedObject>(entityName: HistoryEntryManagedObject.className())
            let predicates = identifiers.map({ NSPredicate(format: "identifier == %@", argumentArray: [$0]) })
            deleteRequest.predicate = NSCompoundPredicate(type: .or, subpredicates: predicates)

            do {
                let entriesToDelete = try context.fetch(deleteRequest)
                for entry in entriesToDelete {
                    context.delete(entry)
                }
                Logger.history.debug("\(entriesToDelete.count) items cleaned from history")
            } catch {
                PixelKit.fire(DebugEvent(GeneralPixel.historyRemoveFailed, error: error))
                self.context.reset()
                return .failure(error)
            }
        }

        do {
            try context.save()
        } catch {
            PixelKit.fire(DebugEvent(GeneralPixel.historyRemoveFailed, error: error))
            context.reset()
            return .failure(error)
        }

        return .success(())
    }

    private func reload(_ context: NSManagedObjectContext) -> Result<BrowsingHistory, Error> {
        let fetchRequest = HistoryEntryManagedObject.fetchRequest() as NSFetchRequest<HistoryEntryManagedObject>
        fetchRequest.returnsObjectsAsFaults = false
        do {
            let historyEntries = try context.fetch(fetchRequest)
            Logger.history.debug("\(historyEntries.count) entries loaded from history")
            let history = BrowsingHistory(historyEntries: historyEntries)
            return .success(history)
        } catch {
            PixelKit.fire(DebugEvent(GeneralPixel.historyReloadFailed, error: error))
            return .failure(error)
        }
    }

    private func clean(_ context: NSManagedObjectContext, until date: Date) -> Result<Void, Error> {
        // Clean using batch delete requests
        let deleteRequest = NSFetchRequest<NSManagedObject>(entityName: HistoryEntryManagedObject.className())
        deleteRequest.predicate = NSPredicate(format: "lastVisit < %@", date as NSDate)
        do {
            let itemsToBeDeleted = try context.fetch(deleteRequest)
            for item in itemsToBeDeleted {
                context.delete(item)
            }
            try context.save()
        } catch {
            PixelKit.fire(DebugEvent(GeneralPixel.historyCleanEntriesFailed, error: error))
            context.reset()
            return .failure(error)
        }

        let visitDeleteRequest = NSFetchRequest<VisitManagedObject>(entityName: VisitManagedObject.className())
        visitDeleteRequest.predicate = NSPredicate(format: "date < %@", date as NSDate)

        do {
            let itemsToBeDeleted = try context.fetch(visitDeleteRequest)
            for item in itemsToBeDeleted {
                context.delete(item)
            }
            try context.save()
            return .success(())
        } catch {
            PixelKit.fire(DebugEvent(GeneralPixel.historyCleanVisitsFailed, error: error))
            context.reset()
            return .failure(error)
        }
    }

    func save(entry: HistoryEntry) -> Future<[(id: Visit.ID, date: Date)], Error> {
        return Future { [weak self] promise in
            self?.context.perform { [weak self] in

                guard let self = self else {
                    promise(.failure(HistoryStoreError.storeDeallocated))
                    return
                }

                // Check for existence
                let fetchRequest = HistoryEntryManagedObject.fetchRequest() as NSFetchRequest<HistoryEntryManagedObject>
                fetchRequest.returnsObjectsAsFaults = false
                fetchRequest.fetchLimit = 1
                fetchRequest.predicate = NSPredicate(format: "identifier == %@", entry.identifier as CVarArg)
                let fetchedObjects: [HistoryEntryManagedObject]
                do {
                    fetchedObjects = try self.context.fetch(fetchRequest)
                } catch {
                    PixelKit.fire(DebugEvent(GeneralPixel.historySaveFailed, error: error))
                    PixelKit.fire(DebugEvent(GeneralPixel.historySaveFailedDaily, error: error), frequency: .legacyDaily)
                    promise(.failure(error))
                    return
                }

                assert(fetchedObjects.count <= 1, "More than 1 history entry with the same identifier")

                let historyEntryManagedObject: HistoryEntryManagedObject
                if let fetchedObject = fetchedObjects.first {
                    // Update existing
                    fetchedObject.update(with: entry)
                    historyEntryManagedObject = fetchedObject
                } else {
                    // Add new
                    let insertedObject = NSEntityDescription.insertNewObject(forEntityName: HistoryEntryManagedObject.className(), into: self.context)
                    guard let historyEntryMO = insertedObject as? HistoryEntryManagedObject else {
                        promise(.failure(HistoryStoreError.savingFailed))
                        return
                    }
                    historyEntryMO.update(with: entry, afterInsertion: true)
                    historyEntryManagedObject = historyEntryMO
                }

                let insertionResult = self.insertNewVisits(of: entry,
                                                           into: historyEntryManagedObject,
                                                           context: self.context)
                switch insertionResult {
                case .failure(let error):
                    PixelKit.fire(DebugEvent(GeneralPixel.historySaveFailed, error: error))
                    PixelKit.fire(DebugEvent(GeneralPixel.historySaveFailedDaily, error: error), frequency: .legacyDaily)
                    context.reset()
                    promise(.failure(error))
                case .success(let visitMOs):
                    do {
                        try self.context.save()
                    } catch {
                        PixelKit.fire(DebugEvent(GeneralPixel.historySaveFailed, error: error))
                        PixelKit.fire(DebugEvent(GeneralPixel.historySaveFailedDaily, error: error), frequency: .legacyDaily)
                        context.reset()
                        promise(.failure(HistoryStoreError.savingFailed))
                        return
                    }

                    let result = visitMOs.compactMap {
                        if let date = $0.date {
                            return (id: $0.objectID.uriRepresentation(), date: date)
                        } else {
                            return nil
                        }
                    }
                    promise(.success(result))
                }
            }
        }
    }

    private func insertNewVisits(of historyEntry: HistoryEntry,
                                 into historyEntryManagedObject: HistoryEntryManagedObject,
                                 context: NSManagedObjectContext) -> Result<[VisitManagedObject], Error> {
        var result: [VisitManagedObject]? = Array()
        historyEntry.visits
            .filter {
                $0.savingState == .initialized
            }
            .forEach {
                $0.savingState = .saved
                let insertionResult = self.insert(visit: $0,
                                                  into: historyEntryManagedObject,
                                                  context: context)
                switch insertionResult {
                case .success(let visitMO): result?.append(visitMO)
                case .failure: result = nil
                }
            }
        if let result {
            return .success(result)
        } else {
            context.reset()
            return .failure(HistoryStoreError.savingFailed)
        }
    }

    private func insert(visit: Visit,
                        into historyEntryManagedObject: HistoryEntryManagedObject,
                        context: NSManagedObjectContext) -> Result<VisitManagedObject, Error> {
        let insertedObject = NSEntityDescription.insertNewObject(forEntityName: VisitManagedObject.className(), into: context)
        guard let visitMO = insertedObject as? VisitManagedObject else {
            PixelKit.fire(DebugEvent(GeneralPixel.historyInsertVisitFailed))
            context.reset()
            return .failure(HistoryStoreError.savingFailed)
        }
        visitMO.update(with: visit, historyEntryManagedObject: historyEntryManagedObject)
        return .success(visitMO)
    }

    func removeVisits(_ visits: [Visit]) -> Future<Void, Error> {
        return Future { [weak self] promise in
            self?.context.perform {
                guard let self = self else {
                    promise(.failure(HistoryStoreError.storeDeallocated))
                    return
                }

                switch self.remove(visits, context: self.context) {
                case .failure(let error):
                    self.context.reset()
                    promise(.failure(error))
                case .success:
                    promise(.success(()))
                }
            }
        }
    }

    private func remove(_ visits: [Visit], context: NSManagedObjectContext) -> Result<Void, Error> {
        // To avoid long predicate, execute multiple times
        let chunkedVisits = visits.chunked(into: 100)

        for visits in chunkedVisits {
            let deleteRequest = NSFetchRequest<VisitManagedObject>(entityName: VisitManagedObject.className())
            let predicates = visits.compactMap({ (visit: Visit) -> NSPredicate? in
                guard let historyEntry = visit.historyEntry else {
                    assertionFailure("No history entry")
                    return nil
                }

                return NSPredicate(format: "historyEntry.identifier == %@ && date == %@", argumentArray: [historyEntry.identifier, visit.date])
            })
            deleteRequest.predicate = NSCompoundPredicate(type: .or, subpredicates: predicates)
            do {
                let visitsToDelete = try self.context.fetch(deleteRequest)
                for visit in visitsToDelete {
                    context.delete(visit)
                }
            } catch {
                PixelKit.fire(DebugEvent(GeneralPixel.historyRemoveVisitsFailed, error: error))
                return .failure(error)
            }
        }

        do {
            try context.save()
        } catch {
            PixelKit.fire(DebugEvent(GeneralPixel.historyRemoveVisitsFailed, error: error))
            context.reset()
            return .failure(error)
        }

        return .success(())
    }

}

fileprivate extension BrowsingHistory {

    init(historyEntries: [HistoryEntryManagedObject]) {
        self = historyEntries.reduce(into: BrowsingHistory(), {
            if let historyEntry = HistoryEntry(historyEntryMO: $1) {
                $0.append(historyEntry)
            }
        })
    }

}

fileprivate extension HistoryEntry {

    convenience init?(historyEntryMO: HistoryEntryManagedObject) {
        guard let url = historyEntryMO.urlEncrypted as? URL,
              let identifier = historyEntryMO.identifier,
              let lastVisit = historyEntryMO.lastVisit else {
            PixelKit.fire(DebugEvent(GeneralPixel.historyEntryDecryptionFailedUnique), frequency: .daily)
            assertionFailure("HistoryEntry: Failed to init HistoryEntry from HistoryEntryManagedObject")
            return nil
        }

        let title = historyEntryMO.titleEncrypted as? String
        let numberOfTotalVisits = historyEntryMO.numberOfTotalVisits
        let numberOfTrackersBlocked = historyEntryMO.numberOfTrackersBlocked
        let blockedTrackingEntities = historyEntryMO.blockedTrackingEntities ?? ""
        let visits = Set(historyEntryMO.visits?.allObjects.compactMap {
            Visit(visitMO: $0 as? VisitManagedObject)
        } ?? [])

        assert(Dictionary(grouping: visits, by: \.date).filter({ $1.count > 1 }).isEmpty, "Duplicate of visit stored")

        self.init(identifier: identifier,
                  url: url,
                  title: title,
                  failedToLoad: historyEntryMO.failedToLoad,
                  numberOfTotalVisits: Int(numberOfTotalVisits),
                  lastVisit: lastVisit,
                  visits: visits,
                  numberOfTrackersBlocked: Int(numberOfTrackersBlocked),
                  blockedTrackingEntities: Set<String>(blockedTrackingEntities.components(separatedBy: "|")),
                  trackersFound: historyEntryMO.trackersFound)

        visits.forEach { visit in
            visit.historyEntry = self
        }
    }

}

fileprivate extension HistoryEntryManagedObject {

    func update(with entry: HistoryEntry, afterInsertion: Bool = false) {
        if afterInsertion {
            identifier = entry.identifier
            urlEncrypted = entry.url as NSURL
        }

        assert(urlEncrypted as? URL == entry.url, "URLs don't match")
        assert(identifier == entry.identifier, "Identifiers don't match")

        urlEncrypted = entry.url as NSURL
        if let title = entry.title, !title.isEmpty {
            self.titleEncrypted = title as NSString
        }
        numberOfTotalVisits = Int64(entry.numberOfTotalVisits)
        lastVisit = entry.lastVisit
        failedToLoad = entry.failedToLoad
        numberOfTrackersBlocked = Int64(entry.numberOfTrackersBlocked)
        blockedTrackingEntities = entry.blockedTrackingEntities.isEmpty ? "" : entry.blockedTrackingEntities.joined(separator: "|")
        trackersFound = entry.trackersFound
    }

}

private extension VisitManagedObject {

    func update(with visit: Visit, historyEntryManagedObject: HistoryEntryManagedObject) {
        date = visit.date
        historyEntry = historyEntryManagedObject
    }

}

private extension Visit {

    convenience init?(visitMO: VisitManagedObject?) {
        guard let visitMO = visitMO,
                let date = visitMO.date else {
            assertionFailure("Bad type or date is nil")
            return nil
        }

        let id = visitMO.objectID.uriRepresentation()
        self.init(date: date, identifier: id)
        savingState = .saved
    }

}
