//
//  PixelStoreTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser
import Combine

final class PixelStoreTests: XCTestCase {
    lazy var container: NSPersistentContainer = {
        CoreData.createInMemoryPersistentContainer(modelName: "PixelDataModel", bundle: Bundle(for: PixelData.self))
    }()
    var context: NSManagedObjectContext!
    var store: LocalPixelDataStore<PixelData>!

    override func setUp() {
        makeStore()
    }

    func makeStore() {
        context = container.newBackgroundContext()
        store = LocalPixelDataStore(context: context, updateModel: PixelData.update)
    }

    func set(_ value: NSObject, forKey key: String) {
        let e = expectation(description: "\(value) saved")
        let completionHandler = { (error: Error?) in
            XCTAssertNil(error)
            e.fulfill()
        }
        switch value {
        case let string as NSString:
            store.set(string as String, forKey: key, completionHandler: completionHandler)
        case let number as NSNumber where [.doubleType, .floatType, .float64Type].contains(CFNumberGetType(number)):
            store.set(number.doubleValue, forKey: key, completionHandler: completionHandler)
        case let number as NSNumber where [.intType, .sInt64Type].contains(CFNumberGetType(number)):
            store.set(number.intValue, forKey: key, completionHandler: completionHandler)
        default:
            fatalError("Unexpected type \((value as? NSNumber).map(CFNumberGetType).map(String.init(describing:)) ?? type(of: value).debugDescription())")
        }
    }

    func addValues(_ values: [String: NSObject]) {
        for (key, value) in values {
            set(value, forKey: key)
        }
    }

    func validateStore(with expectedValues: [String: NSObject]) {
        for (key, value) in expectedValues {
            switch value {
            case let string as NSString:
                XCTAssertEqual(store.value(forKey: key), string as String)
            case let number as NSNumber where [.doubleType, .floatType, .float32Type, .float64Type].contains(CFNumberGetType(number)):
                XCTAssertEqual(store.value(forKey: key), number.doubleValue)
            case let number as NSNumber where [.intType, .sInt64Type].contains(CFNumberGetType(number)):
                XCTAssertEqual(store.value(forKey: key), number.intValue)
            default:
                fatalError("Unexpected type \((value as? NSNumber).map(CFNumberGetType).map(String.init(describing:)) ?? type(of: value).debugDescription())")
            }
        }
    }

    func testWhenValuesAreAddedThenCallbacksAreCalled() {
        let values = ["a": NSNumber(value: 1.23), "b": NSNumber(value: 12), "c": "string" as NSString]
        addValues(values)
        XCTAssertEqual(store.cache, values)
        validateStore(with: values)

        waitForExpectations(timeout: 1)

        XCTAssertEqual(store.cache, values)
        validateStore(with: values)
    }

    func testWhenValuesAreSavedThenTheyAreReloaded() {
        let values = ["a": NSNumber(value: 1.23), "b": NSNumber(value: 12), "c": "string" as NSString]
        addValues(values)
        waitForExpectations(timeout: 0.1)

        makeStore()

        XCTAssertEqual(store.cache, values)
        validateStore(with: values)
    }

    func testWhenValuesAreRemovedThenTheyAreNotInCache() {
        var values = ["a": NSNumber(value: 1.23),
                      "b": NSNumber(value: 12),
                      "c": "string" as NSString,
                      "d": "string 2" as NSString]
        addValues(values)

        for key in ["a", "b", "c"] {
            let e = expectation(description: "\(key) removed")
            store.removeValue(forKey: key) { error in
                XCTAssertNil(error)
                e.fulfill()
            }
            values[key] = nil
        }
        XCTAssertEqual(store.cache, values)
        validateStore(with: values)

        waitForExpectations(timeout: 0.1)

        makeStore()

        XCTAssertEqual(store.cache, values)
        validateStore(with: values)
    }

    func testWhenValuesAreUpdatedThenTheyAreSaved() {
        var values = ["a": NSNumber(value: 1.23),
                      "b": NSNumber(value: 12),
                      "c": "string" as NSString,
                      "d": "string 2" as NSString]
        addValues(values)

        values = ["a": NSNumber(value: 2.23),
                  "b": NSNumber(value: 12),
                  "c": NSNumber(value: 13),
                  "d": "none" as NSString]
        addValues(values)

        XCTAssertEqual(store.cache, values)
        validateStore(with: values)

        waitForExpectations(timeout: 0.1)

        makeStore()

        XCTAssertEqual(store.cache, values)
        validateStore(with: values)
    }

}
