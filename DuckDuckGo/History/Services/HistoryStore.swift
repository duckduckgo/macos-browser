//
//  HistoryStore.swift
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
import CoreData
import Combine
import os.log

protocol HistoryStoring {

    func cleanOld(until date: Date) -> Future<History, Error>
    func removeEntries(_ entries: [HistoryEntry]) -> Future<Void, Error>
    func save(entry: HistoryEntry) -> Future<Void, Error>

}

final class HistoryStore: HistoryStoring {

    init() {}

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    enum HistoryStoreError: Error {
        case storeDeallocated
        case savingFailed
    }

    private lazy var context = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType, name: "History")

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
                    promise(.failure(error))
                case .success:
                    promise(.success(()))
                }
            }
        }
    }

    func cleanOld(until date: Date) -> Future<History, Error> {
        return Future { [weak self] promise in
            self?.context.perform {
                guard let self = self else {
                    promise(.failure(HistoryStoreError.storeDeallocated))
                    return
                }

                switch self.clean(self.context, until: date) {
                case .failure(let error):
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
            let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: HistoryEntryManagedObject.className())
            let predicates = identifiers.map({ NSPredicate(format: "identifier == %@", argumentArray: [$0]) })
            deleteRequest.predicate = NSCompoundPredicate(type: .or, subpredicates: predicates)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs
            do {
                let result = try self.context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                let deletedObjects = result?.result as? [NSManagedObjectID] ?? []
                let changes: [AnyHashable: Any] = [ NSDeletedObjectsKey: deletedObjects ]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                os_log("%d items cleaned from history", log: .history, deletedObjects.count)
            } catch {
                return .failure(error)
            }
        }

        return .success(())
    }

    private func reload(_ context: NSManagedObjectContext) -> Result<History, Error> {
        let fetchRequest = HistoryEntryManagedObject.fetchRequest() as NSFetchRequest<HistoryEntryManagedObject>
        fetchRequest.returnsObjectsAsFaults = false
        do {
            let historyEntries = try context.fetch(fetchRequest)
            os_log("%d items loaded from history", log: .history, historyEntries.count)
            let history = History(historyEntries: historyEntries)
            return .success(history)
        } catch {
            return .failure(error)
        }
    }

    private func clean(_ context: NSManagedObjectContext, until date: Date) -> Result<Void, Error> {
        // Clean using batch delete request
        let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: HistoryEntryManagedObject.className())
        deleteRequest.predicate = NSPredicate(format: "lastVisit < %@", date as NSDate)
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
        batchDeleteRequest.resultType = .resultTypeObjectIDs

        do {
            let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
            let deletedObjects = result?.result as? [NSManagedObjectID] ?? []
            let changes: [AnyHashable: Any] = [ NSDeletedObjectsKey: deletedObjects ]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
            os_log("%d items cleaned from history", log: .history, deletedObjects.count)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func save(entry: HistoryEntry) -> Future<Void, Error> {
        return Future { [weak self] promise in
            self?.context.perform { [weak self] in
                guard let self = self else {
                    promise(.failure(HistoryStoreError.storeDeallocated))
                    return
                }

                // Check for existence
                let fetchRequest = HistoryEntryManagedObject.fetchRequest() as NSFetchRequest<HistoryEntryManagedObject>
                fetchRequest.returnsObjectsAsFaults = false
                fetchRequest.predicate = NSPredicate(format: "identifier == %@", entry.identifier as CVarArg)
                let fetchedObjects: [HistoryEntryManagedObject]
                do {
                    fetchedObjects = try self.context.fetch(fetchRequest)
                } catch {
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
                let insertNewVisitsResult = self.insertNewVisits(of: entry,
                                                                 into: historyEntryManagedObject,
                                                                 context: self.context)
                do {
                    try self.context.save()
                } catch {
                    promise(.failure(HistoryStoreError.savingFailed))
                    return
                }

                promise(insertNewVisitsResult)
            }
        }
    }

    private func insertNewVisits(of historyEntry: HistoryEntry,
                                 into historyEntryManagedObject: HistoryEntryManagedObject,
                                 context: NSManagedObjectContext) -> Result<Void, Error> {
        var success = true
        historyEntry.visits
            .filter {
                $0.savingState == .initialized
            }
            .forEach {
                $0.savingState = .saved
                if case .failure = self.insert(visit: $0,
                                               into: historyEntryManagedObject,
                                               context: context) {
                    success = false
                }
            }
        return success ? .success(()) : .failure(HistoryStoreError.savingFailed)
    }

    private func insert(visit: Visit,
                        into historyEntryManagedObject: HistoryEntryManagedObject,
                        context: NSManagedObjectContext) -> Result<Void, Error> {
        let insertedObject = NSEntityDescription.insertNewObject(forEntityName: VisitManagedObject.className(), into: context)
        guard let visitMO = insertedObject as? VisitManagedObject else {
            return .failure(HistoryStoreError.savingFailed)
        }
        visitMO.update(with: visit, historyEntryManagedObject: historyEntryManagedObject)
        return .success(())
    }

}

fileprivate extension History {

    init(historyEntries: [HistoryEntryManagedObject]) {
        self = historyEntries.reduce(into: History(), {
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
        guard let visitMO = visitMO, let date = visitMO.date else {
            assertionFailure("Bad type or date is nil")
            return nil
        }
        
        self.init(date: date)
    }

}
