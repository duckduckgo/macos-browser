//
//  DownloadListStore.swift
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

protocol DownloadListStoring {

    func fetch(clearingItemsOlderThan date: Date, completionHandler: @escaping (Result<[DownloadListItem], Error>) -> Void)
    func save(_ item: DownloadListItem, completionHandler: ((Error?) -> Void)?)
    func remove(_ item: DownloadListItem, completionHandler: ((Error?) -> Void)?)
    func clear(itemsOlderThan date: Date, completionHandler: ((Error?) -> Void)?)
    func sync()

}

extension DownloadListStoring {

    func clear() {
        clear(itemsOlderThan: .distantFuture, completionHandler: nil)
    }

    func remove(_ item: DownloadListItem) {
        remove(item, completionHandler: nil)
    }

    func save(_ entry: DownloadListItem) {
        save(entry, completionHandler: nil)
    }

}

final class DownloadListStore: DownloadListStoring {

    private var _context: NSManagedObjectContext??
    private var context: NSManagedObjectContext? {
        if case .none = _context {
#if DEBUG
            if AppDelegate.isRunningTests {
                _context = .some(.none)
                return .none
            }
#endif
            _context = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType, name: "Downloads")
        }
        return _context!
    }

    init() {
    }

    init(context: NSManagedObjectContext) {
        self._context = .some(context)
    }

    enum HistoryStoreError: Error {
        case storeDeallocated
        case savingFailed
    }

    private func remove(itemsWithPredicate predicate: NSPredicate, completionHandler: ((Error?) -> Void)?) {
        guard let context = self.context else { return }

        func mainQueueCompletion(_ error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context] in
            let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: DownloadManagedObject.className())
            deleteRequest.predicate = predicate
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                let deletedObjects = result?.result as? [NSManagedObjectID] ?? []
                let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: deletedObjects]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                mainQueueCompletion(nil)
            } catch {
                mainQueueCompletion(error)
            }
        }
    }

    func clear(itemsOlderThan date: Date, completionHandler: ((Error?) -> Void)?) {
        remove(itemsWithPredicate: NSPredicate(format: (\DownloadManagedObject.modified)._kvcKeyPathString! + " < %@", date as NSDate),
               completionHandler: completionHandler)
    }

    func remove(_ item: DownloadListItem, completionHandler: ((Error?) -> Void)?) {
        remove(itemsWithPredicate: NSPredicate(format: (\DownloadManagedObject.identifier)._kvcKeyPathString! + " == %@", item.identifier as CVarArg),
               completionHandler: completionHandler)
    }

    func fetch(completionHandler: @escaping (Result<[DownloadListItem], Error>) -> Void) {
        guard let context = self.context else { return }

        func mainQueueCompletion(_ result: Result<[DownloadListItem], Error>) {
            DispatchQueue.main.async {
                completionHandler(result)
            }
        }

        context.perform { [context] in
            let fetchRequest = DownloadManagedObject.fetchRequest() as NSFetchRequest<DownloadManagedObject>
            fetchRequest.returnsObjectsAsFaults = false
            do {
                let entries = try context.fetch(fetchRequest)
                    .compactMap(DownloadListItem.init(managedObject:))
                mainQueueCompletion(.success(entries))
            } catch {
                mainQueueCompletion(.failure(error))
            }
        }
    }

    func fetch(clearingItemsOlderThan date: Date, completionHandler: @escaping (Result<[DownloadListItem], Error>) -> Void) {
        clear(itemsOlderThan: date) { _ in
            self.fetch(completionHandler: completionHandler)
        }
    }

    func save(_ item: DownloadListItem, completionHandler: ((Error?) -> Void)?) {
        guard let context = self.context else { return }

        func mainQueueCompletion(_ error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context] in
            // Check for existence
            let fetchRequest = DownloadManagedObject.fetchRequest() as NSFetchRequest<DownloadManagedObject>
            fetchRequest.predicate = NSPredicate(format: (\DownloadManagedObject.identifier)._kvcKeyPathString! + " == %@",
                                                 item.identifier as CVarArg)
            let fetchedObjects: [DownloadManagedObject]
            do {
                fetchedObjects = try context.fetch(fetchRequest)
            } catch {
                mainQueueCompletion(error)
                return
            }

            assert(fetchedObjects.count <= 1, "More than 1 downloads item with the same identifier")

            guard let managedObject = fetchedObjects.first
                    ?? NSEntityDescription.insertNewObject(forEntityName: DownloadManagedObject.className(),
                                                           into: context) as? DownloadManagedObject else {
                assertionFailure("DownloadManagedObject insertion failed")
                struct DownloadManagedObjectInsertionError: Error {}
                mainQueueCompletion(DownloadManagedObjectInsertionError())
                return
            }

            managedObject.update(with: item, afterInsertion: fetchedObjects.isEmpty)

            do {
                try context.save()
                mainQueueCompletion(nil)
            } catch {
                mainQueueCompletion(error)
            }
        }
    }

    func sync() {
        let condition = RunLoop.ResumeCondition()
        context?.perform {
            condition.resolve()
        }
        RunLoop.current.run(until: condition)
    }

}

extension DownloadListItem {

    init?(managedObject: DownloadManagedObject) {
        guard let identifier = managedObject.identifier,
              let added = managedObject.added,
              let modified = managedObject.modified,
              let url = managedObject.urlEncrypted as? URL
        else {
            assertionFailure("DownloadListItem: Failed to init from ManagedObject")
            return nil
        }

        let error = (managedObject.errorEncrypted as? NSError).map { nsError in
            FileDownloadError(nsError, isRetryable: managedObject.destinationURLEncrypted as? URL != nil)
        }
        self.init(identifier: identifier,
                  added: added,
                  modified: modified,
                  url: url,
                  websiteURL: managedObject.websiteURLEncrypted as? URL,
                  fileType: managedObject.fileType.map { UTType(rawValue: $0 as CFString) },
                  destinationURL: managedObject.destinationURLEncrypted as? URL,
                  tempURL: managedObject.tempURLEncrypted as? URL,
                  error: error)
    }

}

extension DownloadManagedObject {

    func update(with item: DownloadListItem, afterInsertion: Bool = false) {
        if afterInsertion {
            added = item.added
            identifier = item.identifier
        }

        assert(identifier == item.identifier)
        assert(added == item.added)

        urlEncrypted = item.url as NSURL
        websiteURLEncrypted = item.websiteURL as NSURL?
        modified = item.modified
        fileType = item.fileType?.rawValue as String?
        destinationURLEncrypted = item.destinationURL as NSURL?
        tempURLEncrypted = item.tempURL as NSURL?
        errorEncrypted = item.error as NSError?
    }

}
