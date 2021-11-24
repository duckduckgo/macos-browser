//
//  ConcreteDataStore.swift
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

open class ConcreteDataStore<ManagedObject: NSManagedObject, Container, Element> {
    private let store: DataStore

    private let combine: (inout Container, ManagedObject) throws -> Void
    private let initContainer: () -> Container
    private let update: (ManagedObject, Element) -> Void

    init(store: DataStore,
         initContainer: @escaping () -> Container,
         update: @escaping (ManagedObject, Element) -> Void,
         combine: @escaping (inout Container, ManagedObject) throws -> Void) {
        self.store = store
        self.combine = combine
        self.initContainer = initContainer
        self.update = update
    }

    func load() throws -> Container {
        return try store.load(into: initContainer(), combine)
    }

    func add<Seq: Sequence>(_ objects: Seq) throws
        -> [(element: Element, id: NSManagedObjectID)] where Seq.Element == Element {
        return try store.add(objects, using: self.update)
    }

    func add(_ object: Element) throws -> NSManagedObjectID {
        return try store.add(object, using: update)
    }

    func remove(withPredicate predicate: NSPredicate, completionHandler: ((Error?) -> Void)? = nil) {
        store.remove(objectsOfType: ManagedObject.self, withPredicate: predicate, completionHandler: completionHandler)
    }

    func remove(objectWithId id: NSManagedObjectID, completionHandler: ((Error?) -> Void)? = nil) {
        store.remove(objectWithId: id, completionHandler: completionHandler)
    }

    func clear(completionHandler: ((Error?) -> Void)? = nil) {
        store.clear(objectsOfType: ManagedObject.self, completionHandler: completionHandler)
    }

}
