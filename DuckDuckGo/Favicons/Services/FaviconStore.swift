//
//  FaviconStore.swift
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

import Cocoa
import CoreData
import Combine
import Common
import PixelKit
import os.log

protocol FaviconStoring {

    func loadFavicons() async throws -> [Favicon]
    func save(_ favicons: [Favicon]) async throws
    func removeFavicons(_ favicons: [Favicon]) async throws

    func loadFaviconReferences() async throws -> ([FaviconHostReference], [FaviconUrlReference])
    func save(hostReference: FaviconHostReference) async throws
    func save(urlReference: FaviconUrlReference) async throws
    func remove(hostReferences: [FaviconHostReference]) async throws
    func remove(urlReferences: [FaviconUrlReference]) async throws

}

final class FaviconStore: FaviconStoring {

    enum FaviconStoreError: Error {
        case notLoadedYet
        case savingFailed
    }

    private let context: NSManagedObjectContext

    init() {
        context = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType, name: "Favicons")
    }

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func loadFavicons() async throws -> [Favicon] {
        try await withCheckedThrowingContinuation { [context] continuation in
            context.perform {
                let fetchRequest = FaviconManagedObject.fetchRequest() as NSFetchRequest<FaviconManagedObject>
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(FaviconManagedObject.dateCreated), ascending: true)]
                fetchRequest.returnsObjectsAsFaults = false
                do {
                    let faviconMOs = try context.fetch(fetchRequest)
                    Logger.favicons.debug("\(faviconMOs.count) favicons loaded")
                    let favicons = faviconMOs.compactMap { Favicon(faviconMO: $0) }

                    continuation.resume(returning: favicons)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func removeFavicons(_ favicons: [Favicon]) async throws {
        let identifiers = favicons.map { $0.identifier }
        return try await remove(identifiers: identifiers, entityName: FaviconManagedObject.className())
    }

    func save(_ favicons: [Favicon]) async throws {
        try await withCheckedThrowingContinuation { [context] continuation in
            context.perform {
                do {
                    for favicon in favicons {
                        guard let faviconMO = NSEntityDescription
                            .insertNewObject(forEntityName: FaviconManagedObject.className(), into: context) as? FaviconManagedObject else {
                            assertionFailure("FaviconStore savingFailed")
                            throw FaviconStoreError.savingFailed
                        }
                        faviconMO.update(favicon: favicon)
                    }

                    try context.save()

                    continuation.resume()

                } catch let error as FaviconStoreError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: FaviconStoreError.savingFailed)
                }
            }
        }
    }

    func loadFaviconReferences() async throws -> ([FaviconHostReference], [FaviconUrlReference]) {
        try await withCheckedThrowingContinuation { [context] continuation in
            context.perform {
                let hostFetchRequest = FaviconHostReferenceManagedObject.fetchRequest() as NSFetchRequest<FaviconHostReferenceManagedObject>
                hostFetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(FaviconHostReferenceManagedObject.dateCreated), ascending: true)]
                hostFetchRequest.returnsObjectsAsFaults = false
                let faviconHostReferences: [FaviconHostReference]
                do {
                    let faviconHostReferenceMOs = try context.fetch(hostFetchRequest)
                    Logger.favicons.debug("\(faviconHostReferenceMOs.count) favicon host references loaded")
                    faviconHostReferences = faviconHostReferenceMOs.compactMap { FaviconHostReference(faviconHostReferenceMO: $0) }
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                let urlFetchRequest = FaviconUrlReferenceManagedObject.fetchRequest() as NSFetchRequest<FaviconUrlReferenceManagedObject>
                urlFetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(FaviconUrlReferenceManagedObject.dateCreated), ascending: true)]
                urlFetchRequest.returnsObjectsAsFaults = false
                do {
                    let faviconUrlReferenceMOs = try context.fetch(urlFetchRequest)
                    Logger.favicons.debug("\(faviconUrlReferenceMOs.count) favicon url references loaded")
                    let faviconUrlReferences = faviconUrlReferenceMOs.compactMap { FaviconUrlReference(faviconUrlReferenceMO: $0) }
                    continuation.resume(returning: (faviconHostReferences, faviconUrlReferences))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func save(hostReference: FaviconHostReference) async throws {
        return try await withCheckedThrowingContinuation { [context] continuation in
            context.perform {

                let insertedObject = NSEntityDescription.insertNewObject(forEntityName: FaviconHostReferenceManagedObject.className(), into: context)
                guard let faviconHostReferenceMO = insertedObject as? FaviconHostReferenceManagedObject else {
                    continuation.resume(throwing: FaviconStoreError.savingFailed)
                    return
                }
                faviconHostReferenceMO.update(hostReference: hostReference)

                do {
                    try context.save()
                } catch {
                    continuation.resume(throwing: FaviconStoreError.savingFailed)
                    return
                }

                continuation.resume()
            }
        }
    }

    func save(urlReference: FaviconUrlReference) async throws {
        return try await withCheckedThrowingContinuation { [context] continuation in
            context.perform {

                let insertedObject = NSEntityDescription.insertNewObject(forEntityName: FaviconUrlReferenceManagedObject.className(),
                                                                         into: self.context)
                guard let faviconUrlReferenceMO = insertedObject as? FaviconUrlReferenceManagedObject else {
                    continuation.resume(throwing: FaviconStoreError.savingFailed)
                    return
                }
                faviconUrlReferenceMO.update(urlReference: urlReference)

                do {
                    try self.context.save()
                } catch {
                    continuation.resume(throwing: FaviconStoreError.savingFailed)
                    return
                }

                continuation.resume()
            }
        }
    }

    func remove(hostReferences: [FaviconHostReference]) async throws {
        let identifiers = hostReferences.map { $0.identifier }
        return try await remove(identifiers: identifiers, entityName: FaviconHostReferenceManagedObject.className())
    }

    func remove(urlReferences: [FaviconUrlReference]) async throws {
        let identifiers = urlReferences.map { $0.identifier }
        return try await remove(identifiers: identifiers, entityName: FaviconUrlReferenceManagedObject.className())
    }

    // MARK: - Private

    private func remove(identifiers: [UUID], entityName: String) async throws {
        return try await withCheckedThrowingContinuation { [context] continuation in
            context.perform {
                let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                deleteRequest.predicate = NSPredicate(format: "identifier IN %@", identifiers)

                let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
                batchDeleteRequest.resultType = .resultTypeObjectIDs

                do {
                    let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                    let deletedObjects = result?.result as? [NSManagedObjectID] ?? []
                    let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: deletedObjects]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                    Logger.favicons.debug("\(deletedObjects.count) entries of \(entityName) removed")

                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

}

fileprivate extension Favicon {

    init?(faviconMO: FaviconManagedObject) {
        guard let identifier = faviconMO.identifier,
              let url = faviconMO.urlEncrypted as? URL,
              let documentUrl = faviconMO.documentUrlEncrypted as? URL,
              let dateCreated = faviconMO.dateCreated,
              let relation = Favicon.Relation(rawValue: Int(faviconMO.relation)) else {
            PixelKit.fire(DebugEvent(GeneralPixel.faviconDecryptionFailedUnique), frequency: .daily)
            assertionFailure("Favicon: Failed to init Favicon from FaviconManagedObject")
            return nil
        }

        let image = faviconMO.imageEncrypted as? NSImage

        self.init(identifier: identifier, url: url, image: image, relation: relation, documentUrl: documentUrl, dateCreated: dateCreated)
    }

}

fileprivate extension FaviconHostReference {

    init?(faviconHostReferenceMO: FaviconHostReferenceManagedObject) {
        guard let identifier = faviconHostReferenceMO.identifier,
              let host = faviconHostReferenceMO.hostEncrypted as? String,
              let documentUrl = faviconHostReferenceMO.documentUrlEncrypted as? URL,
              let dateCreated = faviconHostReferenceMO.dateCreated else {
            assertionFailure("Favicon: Failed to init FaviconHostReference from FaviconHostReferenceManagedObject")
            return nil
        }

        let smallFaviconUrl = faviconHostReferenceMO.smallFaviconUrlEncrypted as? URL
        let mediumFaviconUrl = faviconHostReferenceMO.mediumFaviconUrlEncrypted as? URL

        self.init(identifier: identifier,
                  smallFaviconUrl: smallFaviconUrl,
                  mediumFaviconUrl: mediumFaviconUrl,
                  host: host,
                  documentUrl: documentUrl,
                  dateCreated: dateCreated)
    }

}

fileprivate extension FaviconUrlReference {

    init?(faviconUrlReferenceMO: FaviconUrlReferenceManagedObject) {
        guard let identifier = faviconUrlReferenceMO.identifier,
              let documentUrl = faviconUrlReferenceMO.documentUrlEncrypted as? URL,
              let dateCreated = faviconUrlReferenceMO.dateCreated else {
            assertionFailure("Favicon: Failed to init FaviconUrlReference from FaviconUrlReferenceManagedObject")
            return nil
        }

        let smallFaviconUrl = faviconUrlReferenceMO.smallFaviconUrlEncrypted as? URL
        let mediumFaviconUrl = faviconUrlReferenceMO.mediumFaviconUrlEncrypted as? URL

        self.init(identifier: identifier,
                  smallFaviconUrl: smallFaviconUrl,
                  mediumFaviconUrl: mediumFaviconUrl,
                  documentUrl: documentUrl,
                  dateCreated: dateCreated)
    }

}

fileprivate extension FaviconManagedObject {

    func update(favicon: Favicon) {
        identifier = favicon.identifier
        imageEncrypted = favicon.image
        relation = Int64(favicon.relation.rawValue)
        urlEncrypted = favicon.url as NSURL
        documentUrlEncrypted = favicon.documentUrl as NSURL
        dateCreated = favicon.dateCreated
    }

}

fileprivate extension FaviconHostReferenceManagedObject {

    func update(hostReference: FaviconHostReference) {
        identifier = hostReference.identifier
        smallFaviconUrlEncrypted = hostReference.smallFaviconUrl as NSURL?
        mediumFaviconUrlEncrypted = hostReference.mediumFaviconUrl as NSURL?
        documentUrlEncrypted = hostReference.documentUrl as NSURL
        hostEncrypted = hostReference.host as NSString
        dateCreated = hostReference.dateCreated
    }

}

fileprivate extension FaviconUrlReferenceManagedObject {

    func update(urlReference: FaviconUrlReference) {
        identifier = urlReference.identifier
        smallFaviconUrlEncrypted = urlReference.smallFaviconUrl as NSURL?
        mediumFaviconUrlEncrypted = urlReference.mediumFaviconUrl as NSURL?
        documentUrlEncrypted = urlReference.documentUrl as NSURL
        dateCreated = urlReference.dateCreated
    }

}
