//
//  UserDefaultsWrapperTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

private extension UserDefaultsWrapperKey {
    static let test = Self(rawValue: "test")
}

final class UserDefaultsWrapperTests: XCTestCase {

    private let defaults = UserDefaultsMock()

    // MARK: String

    func testStringValueDefaultValue() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: "value", defaults: defaults)
        XCTAssertEqual(wrapper.wrappedValue, "value")
    }

    func testStringValueUpdating() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: "value", defaults: defaults)
        wrapper.wrappedValue = "new"
        XCTAssertEqual(wrapper.wrappedValue, "new")
        XCTAssertEqual(defaults.dictionary as! [String: String], ["test": "new"])
    }

    func testStringValueClear() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: "value", defaults: defaults)
        wrapper.wrappedValue = "new"
        wrapper.clear()
        XCTAssertEqual(wrapper.wrappedValue, "value")
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testStringValueSharedDefaults() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: "value")
        XCTAssertEqual(wrapper.wrappedValue, "value")
        wrapper.wrappedValue = "new"
        XCTAssertEqual(wrapper.wrappedValue, "new")

        UserDefaultsWrapper.clear(.test)
        XCTAssertEqual(wrapper.wrappedValue, "value")
        XCTAssertNil(UserDefaultsWrapper<Any>.sharedDefaults.object(forKey: UserDefaultsWrapperKey.test.rawValue))
    }

    // MARK: Optional<String>

    func testOptionalStringValueDefaultValue() {
        let wrapper = UserDefaultsWrapper<String?>(key: .test, defaultValue: "value", defaults: defaults)
        XCTAssertEqual(wrapper.wrappedValue, "value")
    }

    func testOptionalStringValueNilValue() {
        let wrapper = UserDefaultsWrapper<String?>(key: .test, defaults: defaults)
        XCTAssertNil(wrapper.wrappedValue)
    }

    func testOptionalStringValueUpdating() {
        let wrapper = UserDefaultsWrapper<String?>(key: .test, defaults: defaults)
        wrapper.wrappedValue = "new"
        XCTAssertEqual(wrapper.wrappedValue, "new")
        XCTAssertEqual(defaults.dictionary as! [String: String], ["test": "new"])
    }

    func testOptionalStringValueRemoval() {
        let wrapper = UserDefaultsWrapper<String?>(key: .test, defaults: defaults)
        wrapper.wrappedValue = "new"
        wrapper.wrappedValue = nil
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testOptionalStringValueClear() {
        let wrapper = UserDefaultsWrapper<String?>(key: .test, defaults: defaults)
        wrapper.wrappedValue = "new"
        wrapper.clear()
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testOptionalStringValueSharedDefaults() {
        let wrapper = UserDefaultsWrapper<String?>(key: .test)
        XCTAssertNil(wrapper.wrappedValue)
        wrapper.wrappedValue = "new"
        XCTAssertEqual(wrapper.wrappedValue, "new")

        UserDefaultsWrapper.clear(.test)
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertNil(UserDefaultsWrapper<Any>.sharedDefaults.object(forKey: UserDefaultsWrapperKey.test.rawValue))
    }

    // MARK: Int

    func testIntValueDefaultValue() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: 1, defaults: defaults)
        XCTAssertEqual(wrapper.wrappedValue, 1)
    }

    func testIntValueUpdating() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: 1, defaults: defaults)
        wrapper.wrappedValue = 2
        XCTAssertEqual(wrapper.wrappedValue, 2)
        XCTAssertEqual(defaults.dictionary as! [String: Int], ["test": 2])
    }

    func testIntValueClear() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: 1, defaults: defaults)
        wrapper.wrappedValue = 2
        wrapper.clear()
        XCTAssertEqual(wrapper.wrappedValue, 1)
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testIntValueSharedDefaults() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: 1)
        XCTAssertEqual(wrapper.wrappedValue, 1)
        wrapper.wrappedValue = 2
        XCTAssertEqual(wrapper.wrappedValue, 2)

        UserDefaultsWrapper.clear(.test)
        XCTAssertEqual(wrapper.wrappedValue, 1)
        XCTAssertNil(UserDefaultsWrapper<Any>.sharedDefaults.object(forKey: UserDefaultsWrapperKey.test.rawValue))
    }

    // MARK: Optional<Int>

    func testOptionalIntValueDefaultValue() {
        let wrapper = UserDefaultsWrapper<Int?>(key: .test, defaultValue: 1, defaults: defaults)
        XCTAssertEqual(wrapper.wrappedValue, 1)
    }

    func testOptionalIntValueNilValue() {
        let wrapper = UserDefaultsWrapper<Int?>(key: .test, defaults: defaults)
        XCTAssertNil(wrapper.wrappedValue)
    }

    func testOptionalIntValueUpdating() {
        let wrapper = UserDefaultsWrapper<Int?>(key: .test, defaults: defaults)
        wrapper.wrappedValue = 2
        XCTAssertEqual(wrapper.wrappedValue, 2)
        XCTAssertEqual(defaults.dictionary as! [String: Int], ["test": 2])
    }

    func testOptionalIntValueRemoval() {
        let wrapper = UserDefaultsWrapper<Int?>(key: .test, defaults: defaults)
        wrapper.wrappedValue = 2
        wrapper.wrappedValue = nil
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testOptionalIntValueClear() {
        let wrapper = UserDefaultsWrapper<Int?>(key: .test, defaults: defaults)
        wrapper.wrappedValue = 2
        wrapper.clear()
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testOptionalIntValueSharedDefaults() {
        let wrapper = UserDefaultsWrapper<Int?>(key: .test)
        XCTAssertNil(wrapper.wrappedValue)
        wrapper.wrappedValue = 2
        XCTAssertEqual(wrapper.wrappedValue, 2)

        UserDefaultsWrapper.clear(.test)
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertNil(UserDefaultsWrapper<Any>.sharedDefaults.object(forKey: UserDefaultsWrapperKey.test.rawValue))
    }

    // MARK: RawRepresentable

    func testRawRepresentableValueDefaultValue() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: MyRawRepresentable(rawValue: "value"), defaults: defaults)
        XCTAssertEqual(wrapper.wrappedValue.rawValue, "value")
    }

    func testRawRepresentableValueUpdating() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: MyRawRepresentable(rawValue: "value"), defaults: defaults)
        wrapper.wrappedValue = MyRawRepresentable(rawValue: "new")
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "new"))
        XCTAssertEqual(defaults.dictionary as! [String: String], ["test": "new"])
    }

    func testRawRepresentableValueClear() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: MyRawRepresentable(rawValue: "value"), defaults: defaults)
        wrapper.wrappedValue = MyRawRepresentable(rawValue: "new")
        wrapper.clear()
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "value"))
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testRawRepresentableValueSharedDefaults() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: MyRawRepresentable(rawValue: "value"))
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "value"))
        wrapper.wrappedValue = MyRawRepresentable(rawValue: "new")
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "new"))

        UserDefaultsWrapper.clear(.test)
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "value"))
        XCTAssertNil(UserDefaultsWrapper<Any>.sharedDefaults.object(forKey: UserDefaultsWrapperKey.test.rawValue))
    }

    // MARK: Optional<RawRepresentable>

    struct MyRawRepresentable: RawRepresentable, Equatable {
        let rawValue: String
    }

    func testOptionalRawRepresentableValueDefaultValue() {
        let wrapper = UserDefaultsWrapper<MyRawRepresentable?>(key: .test, defaultValue: MyRawRepresentable(rawValue: "value"), defaults: defaults)
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "value"))
    }

    func testOptionalRawRepresentableValueNilValue() {
        let wrapper = UserDefaultsWrapper<MyRawRepresentable?>(key: .test, defaults: defaults)
        XCTAssertNil(wrapper.wrappedValue)
    }

    func testOptionalRawRepresentableValueUpdating() {
        let wrapper = UserDefaultsWrapper<MyRawRepresentable?>(key: .test, defaults: defaults)
        wrapper.wrappedValue = MyRawRepresentable(rawValue: "new")
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "new"))
        XCTAssertEqual(defaults.dictionary as! [String: String], ["test": "new"])
    }

    func testOptionalRawRepresentableValueRemoval() {
        let wrapper = UserDefaultsWrapper<MyRawRepresentable?>(key: .test, defaults: defaults)
        wrapper.wrappedValue = MyRawRepresentable(rawValue: "new")
        wrapper.wrappedValue = nil
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testOptionalRawRepresentableValueClear() {
        let wrapper = UserDefaultsWrapper<MyRawRepresentable?>(key: .test, defaults: defaults)
        wrapper.wrappedValue = MyRawRepresentable(rawValue: "new")
        wrapper.clear()
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testOptionalRawRepresentableValueSharedDefaults() {
        let wrapper = UserDefaultsWrapper<MyRawRepresentable?>(key: .test)
        XCTAssertNil(wrapper.wrappedValue)
        wrapper.wrappedValue = MyRawRepresentable(rawValue: "new")
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "new"))

        UserDefaultsWrapper.clear(.test)
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertNil(UserDefaultsWrapper<Any>.sharedDefaults.object(forKey: UserDefaultsWrapperKey.test.rawValue))
    }

    // MARK: RawRepresentable with enum Key

    func testRawRepresentableValueDefaultValueWithEnumKey() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: MyRawRepresentable(rawValue: "value"), defaults: defaults)
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "value"))
    }

    func testRawRepresentableValueUpdatingWithEnumKey() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: MyRawRepresentable(rawValue: "value"), defaults: defaults)
        wrapper.wrappedValue = MyRawRepresentable(rawValue: "new")
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "new"))
        XCTAssertEqual(defaults.dictionary as! [String: String], ["test": "new"])
    }

    func testRawRepresentableValueClearWithEnumKey() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: MyRawRepresentable(rawValue: "value"), defaults: defaults)
        wrapper.wrappedValue = MyRawRepresentable(rawValue: "new")
        wrapper.clear()
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "value"))
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testRawRepresentableValueSharedDefaultsWithEnumKey() {
        let wrapper = UserDefaultsWrapper(key: .test, defaultValue: MyRawRepresentable(rawValue: "value"))
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "value"))
        wrapper.wrappedValue = MyRawRepresentable(rawValue: "new")
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "new"))

        UserDefaultsWrapper.clear(.test)
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "value"))
        XCTAssertNil(UserDefaultsWrapper<Any>.sharedDefaults.object(forKey: UserDefaultsWrapperKey.test.rawValue))
    }

    // MARK: Optional<RawRepresentable> with enum Key

    func testOptionalRawRepresentableValueDefaultValueWithEnumKey() {
        let wrapper = UserDefaultsWrapper<MyRawRepresentable?>(key: .lastCrashReportCheckDate, defaultValue: MyRawRepresentable(rawValue: "value"), defaults: defaults)
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "value"))
    }

    func testOptionalRawRepresentableValueNilValueWithEnumKey() {
        let wrapper = UserDefaultsWrapper<MyRawRepresentable?>(key: .lastCrashReportCheckDate, defaults: defaults)
        XCTAssertNil(wrapper.wrappedValue)
    }

    func testOptionalRawRepresentableValueUpdatingWithEnumKey() {
        let wrapper = UserDefaultsWrapper<MyRawRepresentable?>(key: .lastCrashReportCheckDate, defaults: defaults)
        wrapper.wrappedValue = MyRawRepresentable(rawValue: "new")
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "new"))
        XCTAssertEqual(defaults.dictionary as! [String: String], [UserDefaultsWrapper<Any>.Key.lastCrashReportCheckDate.rawValue: "new"])
    }

    func testOptionalRawRepresentableValueRemovalWithEnumKey() {
        let wrapper = UserDefaultsWrapper<MyRawRepresentable?>(key: .lastCrashReportCheckDate, defaults: defaults)
        wrapper.wrappedValue = MyRawRepresentable(rawValue: "new")
        wrapper.wrappedValue = nil
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testOptionalRawRepresentableValueClearWithEnumKey() {
        let wrapper = UserDefaultsWrapper<MyRawRepresentable?>(key: .lastCrashReportCheckDate, defaults: defaults)
        wrapper.wrappedValue = MyRawRepresentable(rawValue: "new")
        wrapper.clear()
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testOptionalRawRepresentableValueSharedDefaultsWithEnumKey() {
        let wrapper = UserDefaultsWrapper<MyRawRepresentable?>(key: .lastCrashReportCheckDate)
        XCTAssertNil(wrapper.wrappedValue)
        wrapper.wrappedValue = MyRawRepresentable(rawValue: "new")
        XCTAssertEqual(wrapper.wrappedValue, MyRawRepresentable(rawValue: "new"))

        UserDefaultsWrapper.clear(.lastCrashReportCheckDate)
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertNil(UserDefaultsWrapper<Any>.sharedDefaults.object(forKey: UserDefaultsWrapper<Any>.Key.lastCrashReportCheckDate.rawValue))
    }

    // MARK: Date

    let date1 = Date()
    let date2 = Date().addingTimeInterval(1)

    func testDateValueDefaultValue() {
        let wrapper = UserDefaultsWrapper(key: .lastCrashReportCheckDate, defaultValue: date1, defaults: defaults)
        XCTAssertEqual(wrapper.wrappedValue, date1)
    }

    func testDateValueUpdating() {
        let wrapper = UserDefaultsWrapper(key: .lastCrashReportCheckDate, defaultValue: date1, defaults: defaults)
        wrapper.wrappedValue = date2
        XCTAssertEqual(wrapper.wrappedValue, date2)
        XCTAssertEqual(defaults.dictionary as! [String: Date], [UserDefaultsWrapper<Any>.Key.lastCrashReportCheckDate.rawValue: date2])
    }

    func testDateValueClear() {
        let wrapper = UserDefaultsWrapper(key: .lastCrashReportCheckDate, defaultValue: date1, defaults: defaults)
        wrapper.wrappedValue = date2
        wrapper.clear()
        XCTAssertEqual(wrapper.wrappedValue, date1)
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testDateValueSharedDefaults() {
        let wrapper = UserDefaultsWrapper(key: .lastCrashReportCheckDate, defaultValue: date1)
        XCTAssertEqual(wrapper.wrappedValue, date1)
        wrapper.wrappedValue = date2
        XCTAssertEqual(wrapper.wrappedValue, date2)

        UserDefaultsWrapper.clear(.lastCrashReportCheckDate)
        XCTAssertEqual(wrapper.wrappedValue, date1)
        XCTAssertNil(UserDefaultsWrapper<Any>.sharedDefaults.object(forKey: UserDefaultsWrapper<Any>.Key.lastCrashReportCheckDate.rawValue))
    }

    // MARK: Optional<Date>

    func testOptionalDateValueDefaultValue() {
        let wrapper = UserDefaultsWrapper<Date?>(key: .lastCrashReportCheckDate, defaultValue: date1, defaults: defaults)
        XCTAssertEqual(wrapper.wrappedValue, date1)
    }

    func testOptionalDateValueNilValue() {
        let wrapper = UserDefaultsWrapper<Date?>(key: .lastCrashReportCheckDate, defaults: defaults)
        XCTAssertNil(wrapper.wrappedValue)
    }

    func testOptionalDateValueUpdating() {
        let wrapper = UserDefaultsWrapper<Date?>(key: .lastCrashReportCheckDate, defaults: defaults)
        wrapper.wrappedValue = date2
        XCTAssertEqual(wrapper.wrappedValue, date2)
        XCTAssertEqual(defaults.dictionary as! [String: Date], [UserDefaultsWrapper<Any>.Key.lastCrashReportCheckDate.rawValue: date2])
    }

    func testOptionalDateValueRemoval() {
        let wrapper = UserDefaultsWrapper<Date?>(key: .lastCrashReportCheckDate, defaults: defaults)
        wrapper.wrappedValue = date2
        wrapper.wrappedValue = nil
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testOptionalDateValueClear() {
        let wrapper = UserDefaultsWrapper<Date?>(key: .lastCrashReportCheckDate, defaults: defaults)
        wrapper.wrappedValue = date2
        wrapper.clear()
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertTrue(defaults.dictionary.isEmpty)
    }

    func testOptionalDateValueSharedDefaults() {
        let wrapper = UserDefaultsWrapper<Date?>(key: .lastCrashReportCheckDate)
        XCTAssertNil(wrapper.wrappedValue)
        wrapper.wrappedValue = date2
        XCTAssertEqual(wrapper.wrappedValue, date2)

        UserDefaultsWrapper.clear(.lastCrashReportCheckDate)
        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertNil(UserDefaultsWrapper<Any>.sharedDefaults.object(forKey: UserDefaultsWrapper<Any>.Key.lastCrashReportCheckDate.rawValue))
    }

}

private final class UserDefaultsMock: UserDefaults {
    var dictionary: [String: Any] = [:]

    init(_ dictionary: [String: Any] = [:]) {
        self.dictionary = dictionary
        super.init(suiteName: nil)!
    }

    override func dictionaryRepresentation() -> [String: Any] {
        dictionary
    }

    override func object(forKey key: String) -> Any? {
        dictionary[key]
    }

    override func set(_ value: Any?, forKey key: String) {
        dictionary[key] = value
    }

    override func removeObject(forKey key: String) {
        dictionary[key] = nil
    }

}
