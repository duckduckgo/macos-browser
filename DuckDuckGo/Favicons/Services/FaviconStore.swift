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
import os.log

protocol FaviconStoring {

    func loadFavicons() -> Future<[Favicon], Error>
    func save(favicon: Favicon) -> Future<Void, Error>
    func removeFavicons(_ favicons: [Favicon]) -> Future<Void, Error>

    func loadFaviconReferences() -> Future<([FaviconHostReference], [FaviconUrlReference]), Error>
    func save(hostReference: FaviconHostReference) -> Future<Void, Error>
    func save(urlReference: FaviconUrlReference) -> Future<Void, Error>
    func remove(hostReferences: [FaviconHostReference]) -> Future<Void, Error>
    func remove(urlReferences: [FaviconUrlReference]) -> Future<Void, Error>

}

final class FaviconStore: FaviconStoring {

    enum FaviconStoreError: Error {
        case notLoadedYet
        case storeDeallocated
        case savingFailed
    }

    private lazy var context = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType, name: "Favicons")

    init() {}

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func loadFavicons() -> Future<[Favicon], Error> {
        return Future { [weak self] promise in
            self?.context.perform {
                guard let self = self else {
                    promise(.failure(FaviconStoreError.storeDeallocated))
                    return
                }

                let fetchRequest = FaviconManagedObject.fetchRequest() as NSFetchRequest<FaviconManagedObject>
                fetchRequest.returnsObjectsAsFaults = false
                do {
                    let faviconMOs = try self.context.fetch(fetchRequest)
                    os_log("%d favicons loaded ", log: .favicons, faviconMOs.count)
                    let favicons = faviconMOs.compactMap { Favicon(faviconMO: $0) }
                    promise(.success(favicons))
                } catch {
                    promise(.failure(error))
                }
            }
        }
    }

    func removeFavicons(_ favicons: [Favicon]) -> Future<Void, Error> {
        //TODO:
        return Future { [weak self] promise in
            promise(.success(()))
        }
    }

    func save(favicon: Favicon) -> Future<Void, Error> {
        return Future { [weak self] promise in
            self?.context.perform { [weak self] in
                guard let self = self else {
                    promise(.failure(FaviconStoreError.storeDeallocated))
                    return
                }

                //TODO: duplicates!?
                let insertedObject = NSEntityDescription.insertNewObject(forEntityName: FaviconManagedObject.className(), into: self.context)
                guard let faviconMO = insertedObject as? FaviconManagedObject else {
                    promise(.failure(FaviconStoreError.savingFailed))
                    return
                }
                faviconMO.update(favicon: favicon)

                do {
                    try self.context.save()
                } catch {
                    promise(.failure(FaviconStoreError.savingFailed))
                    return
                }

                promise(.success(()))
            }
        }
    }

    func loadFaviconReferences() -> Future<([FaviconHostReference], [FaviconUrlReference]), Error> {
        return Future { [weak self] promise in
            self?.context.perform {
                guard let self = self else {
                    promise(.failure(FaviconStoreError.storeDeallocated))
                    return
                }

                let hostFetchRequest = FaviconHostReferenceManagedObject.fetchRequest() as NSFetchRequest<FaviconHostReferenceManagedObject>
                hostFetchRequest.returnsObjectsAsFaults = false
                let faviconHostReferences: [FaviconHostReference]
                do {
                    let faviconHostReferenceMOs = try self.context.fetch(hostFetchRequest)
                    os_log("%d favicon host references loaded ", log: .favicons, faviconHostReferenceMOs.count)
                    faviconHostReferences = faviconHostReferenceMOs.compactMap { FaviconHostReference(faviconHostReferenceMO: $0) }
                } catch {
                    promise(.failure(error))
                    return
                }

                let urlFetchRequest = FaviconUrlReferenceManagedObject.fetchRequest() as NSFetchRequest<FaviconUrlReferenceManagedObject>
                urlFetchRequest.returnsObjectsAsFaults = false
                do {
                    let faviconUrlReferenceMOs = try self.context.fetch(urlFetchRequest)
                    os_log("%d favicon url references loaded ", log: .favicons, faviconUrlReferenceMOs.count)
                    let faviconUrlReferences = faviconUrlReferenceMOs.compactMap { FaviconUrlReference(faviconUrlReferenceMO: $0) }
                    promise(.success((faviconHostReferences, faviconUrlReferences)))
                } catch {
                    promise(.failure(error))
                }
            }
        }
    }

    func save(hostReference: FaviconHostReference) -> Future<Void, Error> {
        return Future { [weak self] promise in
            self?.context.perform { [weak self] in
                guard let self = self else {
                    promise(.failure(FaviconStoreError.storeDeallocated))
                    return
                }

                //TODO: duplicates!?
                let insertedObject = NSEntityDescription.insertNewObject(forEntityName: FaviconHostReferenceManagedObject.className(),
                                                                         into: self.context)
                guard let faviconHostReferenceMO = insertedObject as? FaviconHostReferenceManagedObject else {
                    promise(.failure(FaviconStoreError.savingFailed))
                    return
                }
                faviconHostReferenceMO.update(hostReference: hostReference)

                do {
                    try self.context.save()
                } catch {
                    promise(.failure(FaviconStoreError.savingFailed))
                    return
                }

                promise(.success(()))
            }
        }
    }

    func save(urlReference: FaviconUrlReference) -> Future<Void, Error> {
        return Future { [weak self] promise in
            self?.context.perform { [weak self] in
                guard let self = self else {
                    promise(.failure(FaviconStoreError.storeDeallocated))
                    return
                }

                //TODO: duplicates!?
                let insertedObject = NSEntityDescription.insertNewObject(forEntityName: FaviconUrlReferenceManagedObject.className(),
                                                                         into: self.context)
                guard let faviconUrlReferenceMO = insertedObject as? FaviconUrlReferenceManagedObject else {
                    promise(.failure(FaviconStoreError.savingFailed))
                    return
                }
                faviconUrlReferenceMO.update(urlReference: urlReference)

                do {
                    try self.context.save()
                } catch {
                    promise(.failure(FaviconStoreError.savingFailed))
                    return
                }

                promise(.success(()))
            }
        }
    }

    func remove(hostReferences: [FaviconHostReference]) -> Future<Void, Error> {
        //TODO:
        return Future { [weak self] promise in
            promise(.success(()))
        }
    }

    func remove(urlReferences: [FaviconUrlReference]) -> Future<Void, Error> {
        //TODO:
        return Future { [weak self] promise in
            promise(.success(()))
        }
    }

}

fileprivate extension Favicon {

    init?(faviconMO: FaviconManagedObject) {
        guard let identifier = faviconMO.identifier,
              let url = faviconMO.urlEncrypted as? URL,
              let image = faviconMO.imageEncrypted as? NSImage,
              let dateCreated = faviconMO.dateCreated,
              let relation = Favicon.Relation(rawValue: Int(faviconMO.relation)) else {
            assertionFailure("Favicon: Failed to init Favicon from FaviconManagedObject")
            return nil
        }

        self.init(identifier: identifier, url: url, image: image, relation: relation, dateCreated: dateCreated)
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
