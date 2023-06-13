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

extension NSCoder {

    func encode<T: NSObject>(forKey key: String) -> (T) -> Void where T: NSSecureCoding {
        return { object in
            self.encode(object, forKey: key)
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
        var result: Result<T, Error>?
        CallbackEscapeHelper.withNonescapingCallback({
            result = Result {
                try creator(self)
            }
        }) { callback in
            withCallback(callback) {
                withSafeUnarchiverHelperReplacement(for: T.self) {
                    _=decodeObject(of: [NSArray.self, SafeUnarchiverHelper.self], forKey: key)
                }
            }
        }

        return try result?.get() ?? { throw errorOrKeyNotFound(key) }()
    }

    public func decodeIfPresent<T>(at key: String, using creator: ((NSCoder) throws -> T?)) throws -> T? {
        var result: Result<T?, Error>?
        CallbackEscapeHelper.withNonescapingCallback({
            result = Result {
                try creator(self)
            }
        }) { callback in
            withCallback(callback) {
                withSafeUnarchiverHelperReplacement(for: T.self) {
                    _=decodeObject(of: [NSArray.self, SafeUnarchiverHelper.self], forKey: key)
                }
            }
        }

        return try result?.get() ?? { throw errorOrKeyNotFound(key) }()
    }

    func decodeArray<T>(at key: String, using creator: ((NSCoder) throws -> T?)) throws -> [T] {
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
                (self as? NSKeyedUnarchiver)?.finishDecoding()
            }

        }) { callback in
            withCallback(callback) {
                withSafeUnarchiverHelperReplacement(for: T.self) {
                    _=decodeObject(of: [NSArray.self, SafeUnarchiverHelper.self], forKey: key)
                }
            }
        }

        return try result?.get() ?? { throw errorOrKeyNotFound(key) }()
    }

    private func errorOrKeyNotFound(_ key: String) -> Error {
        struct StringKey: CodingKey {
            var intValue: Int? { nil }
            init?(intValue: Int) { fatalError() }

            let stringValue: String
            init(stringValue: String) {
                self.stringValue = stringValue
            }
        }
        return self.error ?? DecodingError.keyNotFound(StringKey(stringValue: key), .init(codingPath: [StringKey(stringValue: key)], debugDescription: "key not found"))
    }

    private func withSafeUnarchiverHelperReplacement<T>(for _: T.Type, do job: () -> Void) {
        let className = (T.self as? AnyClass).map(NSStringFromClass) ?? "\(T.self)"
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
            return nil
        }

        func encode(with coder: NSCoder) {
        }

    }

}
