//
//  NSCoderExtensions.swift
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

protocol NSSecureEncodable {
    static var className: String? { get }
    func encode(with coder: NSCoder)
}
extension NSSecureEncodable {
    static var className: String? { nil }
}

extension NSCoder {

    enum CodingKey: Swift.CodingKey {
        case string(String)
        case int(Int)

        var intValue: Int? {
            if case .int(let value) = self { return value }
            return nil
        }

        var stringValue: String {
            switch self {
            case .string(let value):
                return value
            case .int(let value):
                return String(value)
            }
        }

        init(intValue: Int) {
            self = .int(intValue)
        }

        init(stringValue: String) {
            self = .string(stringValue)
        }

        static let rootObject = CodingKey(stringValue: NSKeyedArchiveRootObjectKey)
    }

    fileprivate static func className(for type: Any.Type) -> String {
        let className = (type as? NSSecureEncodable.Type)?.className
            ?? String(((type as? AnyClass).map(NSStringFromClass) ?? "\(type)").split(separator: ".").last!)
        assert(!className.hasPrefix("Optional<"))
        return className
    }

    func encode<T: NSSecureEncodable>(_ value: T, forKey key: String) {
        let archiver = self as! NSKeyedArchiver // swiftlint:disable:this force_cast

        let helper = ArchiverHelper(value: value)
        archiver.encode(helper, forKey: key)
    }

    func encode<T: NSSecureEncodable>(_ array: [T], forKey key: String) {
        let archiver = self as! NSKeyedArchiver // swiftlint:disable:this force_cast

        let array = array.map(ArchiverHelper.init(value:)) as NSArray
        archiver.encode(array, forKey: key)
    }

    func encode<T: NSObject>(forKey key: String) -> (T) -> Void where T: NSSecureCoding {
        return { object in
            self.encode(object, forKey: key)
        }
    }

    func encode<T: NSSecureEncodable>(forKey key: String) -> (T) -> Void {
        return { object in
            self.encode(object, forKey: key)
        }
    }

    func encode<T: NSSecureEncodable>(forKey key: String) -> ([T]) -> Void {
        return { array in
            self.encode(array, forKey: key)
        }
    }

    func encode<T: _ObjectiveCBridgeable>(forKey key: String) -> (T) -> Void
    where T._ObjectiveCType: NSObject, T._ObjectiveCType: NSSecureCoding {

        return { object in
            self.encode(object._bridgeToObjectiveC(), forKey: key)
        }
    }

    func encode(forKey key: String) -> (Int) -> Void {
        return { integer in
            self.encode(integer, forKey: key)
        }
    }

    func decodeIfPresent(at key: String) -> Int? {
        guard containsValue(forKey: key) else { return nil }
        return decodeInteger(forKey: key)
    }

    func decodeIfPresent<T: NSObject>(at key: String) -> T? where T: NSSecureCoding {
        guard containsValue(forKey: key) else { return nil }
        return decodeObject(of: T.self, forKey: key)
    }

    func decodeIfPresent<T: _ObjectiveCBridgeable>(at key: String) -> T?
    where T._ObjectiveCType: NSObject, T._ObjectiveCType: NSSecureCoding {

        guard containsValue(forKey: key),
              let obj = decodeObject(of: T._ObjectiveCType.self, forKey: key)
        else {
            return nil
        }
        return T._unconditionallyBridgeFromObjectiveC(obj)
    }

    public func decode<T>(at key: String, using creator: ((NSCoder) throws -> T)) throws -> T {
        try autoreleasepool {
            var result: Result<T, Error>?
            CallbackEscapeHelper.withNonescapingCallback({
                result = Result {
                    try creator(self)
                }
            }) { callback in
                withCallback(callback) {
                    withSafeUnarchiverHelperReplacement(for: T.self) {
                        _=decodeObject(of: [SafeUnarchiverHelper.self], forKey: key)
                    }
                }
            }

            return try result?.get() ?? { throw errorOrKeyNotFound(key) }()
        }
    }

    public func decodeIfPresent<T>(at key: String, using creator: ((NSCoder) throws -> T?)) throws -> T? {
        try autoreleasepool {
            var result: Result<T?, Error>?
            CallbackEscapeHelper.withNonescapingCallback({
                result = Result {
                    try creator(self)
                }
            }) { callback in
                withCallback(callback) {
                    withSafeUnarchiverHelperReplacement(for: T.self) {
                        _=decodeObject(of: [SafeUnarchiverHelper.self], forKey: key)
                    }
                }
            }

            return try result?.get() ?? { throw errorOrKeyNotFound(key) }()
        }
    }

    func decodeArray<T>(at key: String, using creator: ((NSCoder) throws -> T?)) throws -> [T] {
        try autoreleasepool {
            var result: Result<[T], Error>?
            CallbackEscapeHelper.withNonescapingCallback({
                do {
                    guard let item = try creator(self) else { return }

                    var items: [T] = try result?.get() ?? []
                    result = nil
                    items.append(item)

                    result = .success(items)

                } catch {
                    result = .failure(error)
                    (self as? NSKeyedUnarchiver)?.failWithError(error)
                }

            }) { callback in
                withCallback(callback) {
                    withSafeUnarchiverHelperReplacement(for: T.self) {
                        _=decodeObject(of: [NSArray.self, SafeUnarchiverHelper.self], forKey: key)
                    }
                }
            }

            return try result?.get() ?? []
        }
    }

    private func errorOrKeyNotFound(_ key: String) -> Error {
        let key = CodingKey(stringValue: key)
        return self.error ?? DecodingError.keyNotFound(key, .init(codingPath: [key], debugDescription: "key not found"))
    }

    private func withSafeUnarchiverHelperReplacement<T>(for _: T.Type, do job: () -> Void) {
        let className = Self.className(for: T.self)
        let unarchiver = self as! NSKeyedUnarchiver // swiftlint:disable:this force_cast

        unarchiver.setClass(SafeUnarchiverHelper.self, forClassName: className)
        job()
        unarchiver.setClass(nil, forClassName: className)
    }

    private func withCallback(_ callback: @escaping () -> Void, do job: () -> Void) {
        SafeUnarchiverHelper.$callback.withValue(SafeUnarchiverHelper.Callback(run: callback), operation: job)
    }

    @objc(SafeUnarchiverHelper)
    final private class SafeUnarchiverHelper: NSObject, NSSecureCoding {
        struct Callback: @unchecked Sendable {
            let run: () -> Void
        }
        @TaskLocal static var callback: Callback?

        public static var supportsSecureCoding: Bool { true }

        required init?(coder: NSCoder) {
            Self.callback!.run()
        }

        func encode(with coder: NSCoder) {
        }

    }

    @objc(ArchiverHelper)
    final private class ArchiverHelper: NSObject, NSSecureCoding {
        let value: NSSecureEncodable
        public static var supportsSecureCoding: Bool { true }
        private static var classCache = [String: AnyClass]()

        override var classForCoder: AnyClass {
            let className = NSCoder.className(for: type(of: value))
            if let cls = NSClassFromString(className) ?? Self.classCache[className] {
                return cls
            }
            let cls: AnyClass = objc_allocateClassPair(ArchiverHelper.self, className, 0) ?? ArchiverHelper.self
            Self.classCache[className] = cls
            return cls
        }
        init(value: NSSecureEncodable) {
            self.value = value
        }

        required init?(coder: NSCoder) {
            fatalError()
        }

        func encode(with coder: NSCoder) {
            value.encode(with: coder)
        }

    }

}
