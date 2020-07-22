//
//  HistoryStore.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import os.log

protocol HistoryStore {

    func loadWebsiteVisits(textQuery: String?, limit: Int, completion: @escaping ([WebsiteVisit]?, Error?) -> Void)
    func saveWebsiteVisit(_ websiteVisit: WebsiteVisit)
    func removeAllWebsiteVisits()

}

class LocalHistoryStore: HistoryStore {

    enum Constants {
        static let websiteVisitEntity = "WebsiteVisit"
    }

    init(database: Database) {
        self.database = database
    }

    convenience init() {
        self.init(database: Database.shared)
    }

    let database: Database

    enum LocalHistoryStoreError: Error {
        case loadingFailed
    }

    func loadWebsiteVisits(textQuery: String?, limit: Int, completion: ([WebsiteVisit]?, Error?) -> Void) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.websiteVisitEntity)

        if let textQuery = textQuery {
            let urlPredicate = NSPredicate(format: "%K CONTAINS[c] %@", "url", textQuery)
            let titlePredicate = NSPredicate(format: "%K CONTAINS[c] %@", "title", textQuery)
            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [titlePredicate, urlPredicate])
        }
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = limit

        do {
            guard let managedObjects = try database.context.fetch(fetchRequest) as? [WebsiteVisitManagedObject] else {
                os_log("LocalHistoryStore: Unwrapping fetch request failed", log: OSLog.Category.general, type: .error)
                completion(nil, LocalHistoryStoreError.loadingFailed)
                return
            }
            let websiteVisits: [WebsiteVisit] = managedObjects.compactMap {
                guard let url = $0.url,
                      let date = $0.date else {
                    os_log("LocalHistoryStore: Unwrapping fetch request failed", log: OSLog.Category.general, type: .error)
                    return nil
                }
                return WebsiteVisit(url: url, title: $0.title, date: date) }

            completion(websiteVisits, nil)
        } catch let error {
            os_log("", log: OSLog.Category.general, type: .error)
            completion(nil, error)
        }
    }

    func saveWebsiteVisit(_ websiteVisit: WebsiteVisit) {
        guard let websiteVisitEntity = NSEntityDescription.entity(forEntityName: Constants.websiteVisitEntity, in: database.context) else {
            os_log("LocalHistoryStore: Failed to get entity", log: OSLog.Category.general, type: .error)
            return
        }
        let managedObject = WebsiteVisitManagedObject(entity: websiteVisitEntity, insertInto: database.context)
        managedObject.url = websiteVisit.url
        managedObject.date = websiteVisit.date
        managedObject.title = websiteVisit.title

        do {
            try database.context.save()
        } catch let error {
            os_log("LocalHistoryStore: Failed to save context - %s",
                   log: OSLog.Category.general,
                   type: .error,
                   error.localizedDescription)
        }

    }

    func removeAllWebsiteVisits() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.websiteVisitEntity)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try database.context.execute(deleteRequest)
            try database.context.save()
        } catch let error {
            os_log("LocalHistoryStore: Failed to remove all website visits - %s",
                   log: OSLog.Category.general,
                   type: .error,
                   error.localizedDescription)
        }
    }
    
}
