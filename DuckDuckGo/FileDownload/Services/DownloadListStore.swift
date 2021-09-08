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
    func save(_ entry: DownloadListItem, completionHandler: ((Result<DownloadManagedObject, Error>) -> Void)?)
    func clear(itemsOlderThan date: Date, completionHandler: ((Error?) -> Void)?)
    func sync()

}

extension DownloadListStoring {
    func clear() {
        clear(itemsOlderThan: .distantFuture, completionHandler: nil)
    }
    func save(_ entry: DownloadListItem) {
        save(entry, completionHandler: nil)
    }
}

final class DownloadListStore: DownloadListStoring {

    init() {}

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    enum HistoryStoreError: Error {
        case storeDeallocated
        case savingFailed
    }

    private lazy var context = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType, name: "Downloads")

    func clear(itemsOlderThan date: Date, completionHandler: ((Error?) -> Void)?) {
        func mainQueueCompletion(error: Error?) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }

        context.perform { [context] in
            let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: DownloadManagedObject.className())
            deleteRequest.predicate = NSPredicate(format: (\DownloadManagedObject.modified)._kvcKeyPathString! + " < %@", date as NSDate)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                let deletedObjects = result?.result as? [NSManagedObjectID] ?? []
                let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: deletedObjects]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                mainQueueCompletion(error: nil)
            } catch {
                mainQueueCompletion(error: error)
            }
        }
    }

    func fetch(completionHandler: @escaping (Result<[DownloadListItem], Error>) -> Void) {
        func mainQueueCompletion(_ result: Result<[DownloadListItem], Error>) {
            DispatchQueue.main.async {
                completionHandler(result)
            }
        }
        context.perform { [context] in
            let fetchRequest = DownloadManagedObject.fetchRequest() as NSFetchRequest<DownloadManagedObject>
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: (\DownloadManagedObject.modified)._kvcKeyPathString, ascending: false)]
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

    func save(_ entry: DownloadListItem, completionHandler: ((Result<DownloadManagedObject, Error>) -> Void)?) {
        func mainQueueCompletion(_ result: Result<DownloadManagedObject, Error>) {
            guard completionHandler != nil else { return }
            DispatchQueue.main.async {
                completionHandler?(result)
            }
        }
        context.perform { [context] in
            // Check for existence
            let fetchRequest = DownloadManagedObject.fetchRequest() as NSFetchRequest<DownloadManagedObject>
            fetchRequest.predicate = NSPredicate(format: (\DownloadManagedObject.identifier)._kvcKeyPathString! + " == %@",
                                                 entry.identifier as CVarArg)
            let fetchedObjects: [DownloadManagedObject]
            do {
                fetchedObjects = try context.fetch(fetchRequest)
            } catch {
                mainQueueCompletion(.failure(error))
                return
            }

            assert(fetchedObjects.count <= 1, "More than 1 downloads entry with the same identifier")

            guard let managedObject = fetchedObjects.first
                    ?? NSEntityDescription.insertNewObject(forEntityName: DownloadManagedObject.className(),
                                                           into: context) as? DownloadManagedObject else {
                assertionFailure("DownloadManagedObject insertion failed")
                struct DownloadManagedObjectInsertionError: Error {}
                mainQueueCompletion(.failure(DownloadManagedObjectInsertionError()))
                return
            }

            managedObject.update(with: entry, afterInsertion: fetchedObjects.isEmpty)

            do {
                try context.save()
                mainQueueCompletion(.success(managedObject))
            } catch {
                mainQueueCompletion(.failure(error))
            }
        }
    }

    func sync() {
        context.performAndWait {}
    }

}

extension DownloadListItem {

    init?(managedObject: DownloadManagedObject) {
        guard let identifier = managedObject.identifier,
              let added = managedObject.added,
              let modified = managedObject.modified,
              let url = managedObject.urlEncrypted as? URL
        else {
            assertionFailure("DownloadsHistoryEntry: Failed to init from ManagedObject")
            return nil
        }

        self.init(identifier: identifier,
                  added: added,
                  modified: modified,
                  url: url,
                  websiteURL: managedObject.websiteURLEncrypted as? URL,
                  fileType: managedObject.fileType.map { UTType(rawValue: $0 as CFString) },
                  destinationURL: managedObject.destinationURLEncrypted as? URL,
                  tempURL: managedObject.tempURLEncrypted as? URL,
                  error: (managedObject.errorEncrypted as? NSError).map(FileDownloadError.init))
    }

}

extension DownloadManagedObject {

    func update(with entry: DownloadListItem, afterInsertion: Bool = false) {
        if afterInsertion {
            added = entry.added
            identifier = entry.identifier
        }

        assert(identifier == entry.identifier)
        assert(identifier == entry.identifier)

        urlEncrypted = entry.url as NSURL
        websiteURLEncrypted = entry.websiteURL as NSURL?
        modified = entry.modified
        fileType = entry.fileType?.rawValue as String?
        destinationURLEncrypted = entry.destinationURL as NSURL?
        tempURLEncrypted = entry.tempURL as NSURL?
        errorEncrypted = entry.error as NSError?
    }

}
