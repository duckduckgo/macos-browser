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

    func loadWebsiteVisits(query: String, limit: Int, completion: @escaping ([WebsiteVisit]?, Error?) -> Void)
    func saveWebsiteVisit(_ websiteVisit: WebsiteVisit)

}

class LocalHistoryStore: HistoryStore {

    let context = Database.shared.context

    enum LocalHistoryStoreError: Error {
        case loadingFailed
    }

    func loadWebsiteVisits(query: String, limit: Int, completion: @escaping ([WebsiteVisit]?, Error?) -> Void) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "WebsiteVisit")
        let urlPredicate = NSPredicate(format: "%K CONTAINS[c] %@", "url", query)
        let titlePredicate = NSPredicate(format: "%K CONTAINS[c] %@", "title", query)
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [titlePredicate, urlPredicate])
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = limit

        do {
            guard let managedObjects = try context.fetch(fetchRequest) as? [NSManagedObject] else {
                os_log("LocalHistoryStore: Unwrapping fetch request failed", log: OSLog.Category.general, type: .error)
                completion(nil, LocalHistoryStoreError.loadingFailed)
                return
            }
            let websiteVisits: [WebsiteVisit] = managedObjects.compactMap {
                guard let url = $0.value(forKey: "url") as? URL,
                      let title = $0.value(forKey: "title") as? String,
                      let date = $0.value(forKey: "date") as? Date else {
                    os_log("LocalHistoryStore: Unwrapping fetch request failed", log: OSLog.Category.general, type: .error)
                    return nil
                }
                return WebsiteVisit(url: url, title: title, date: date) }

            completion(websiteVisits, nil)
        } catch let error {
            os_log("", log: OSLog.Category.general, type: .error)
            completion(nil, error)
        }
    }

    func saveWebsiteVisit(_ websiteVisit: WebsiteVisit) {
        guard let websiteVisitEntity = NSEntityDescription.entity(forEntityName: "WebsiteVisit", in: context) else {
            os_log("LocalHistoryStore: Failed to get entity", log: OSLog.Category.general, type: .error)
            return
        }
        let managedObject = NSManagedObject(entity: websiteVisitEntity, insertInto: context)
        managedObject.setValue(websiteVisit.url, forKey: "url")
        managedObject.setValue(websiteVisit.date, forKey: "date")
        managedObject.setValue(websiteVisit.title, forKey: "title")

        do {
            try context.save()
        } catch let error {
            os_log("LocalHistoryStore: Failed to save context - %s",
                   log: OSLog.Category.general,
                   type: .error,
                   error.localizedDescription)
        }

    }
    
}
