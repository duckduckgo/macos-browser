//
//  StatePersistenceService.swift
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

final class StatePersistenceService {
    private let fileStore: FileStore
    private let fileName: String
    private var lastSessionStateArchive: Data?
    private let queue = DispatchQueue(label: "StateRestorationManager.queue", qos: .background)
    private var job: DispatchWorkItem?

    private(set) var error: Error?

    init(fileStore: FileStore, fileName: String) {
        self.fileStore = fileStore
        self.fileName = fileName
    }

    var canRestoreLastSessionState: Bool {
        lastSessionStateArchive != nil
    }

    @MainActor
    func persistState(using encoder: @escaping @MainActor (NSCoder) -> Void, sync: Bool = false) {
        dispatchPrecondition(condition: .onQueue(.main))

        let data = archive(using: encoder)
        write(data, sync: sync)
    }

    func clearState(sync: Bool = false) {
        dispatchPrecondition(condition: .onQueue(.main))

        job?.cancel()
        job = DispatchWorkItem {
            let location = URL.persistenceLocation(for: self.fileName)
            self.fileStore.remove(fileAtURL: location)
        }
        queue.dispatch(job!, sync: sync)
    }

    func flush() {
        queue.sync {}
    }

    func loadLastSessionState() {
        lastSessionStateArchive = loadStateFromFile()
    }

    func removeLastSessionState() {
        lastSessionStateArchive = nil
    }

    @MainActor
    func restoreState(using restore: @escaping @MainActor (SafeUnarchiver) throws -> Void) throws {
        guard let encryptedData = lastSessionStateArchive ?? loadStateFromFile() else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        try restoreState(from: encryptedData, using: restore)
    }

    // MARK: - Private

    @MainActor
    private func archive(using encoder: @escaping @MainActor (NSCoder) -> Void) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        encoder(archiver)
        return archiver.encodedData
    }

    private func write(_ data: Data, sync: Bool) {
        job?.cancel()
        job = DispatchWorkItem {
            self.error = nil
            let location = URL.persistenceLocation(for: self.fileName)
            if !self.fileStore.persist(data, url: location) {
                self.error = CocoaError(.fileWriteNoPermission)
            }
        }
        queue.dispatch(job!, sync: sync)
    }

    private func loadStateFromFile() -> Data? {
        fileStore.loadData(at: URL.persistenceLocation(for: self.fileName), decryptIfNeeded: false)
    }

    @MainActor
    private func restoreState(from archive: Data, using restore: @escaping @MainActor (SafeUnarchiver) throws -> Void) throws {
        guard let data = fileStore.decrypt(archive) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let unarchiver = try SafeUnarchiverImp(forReadingFrom: data)
        try restore(unarchiver)
    }

}

protocol SafeUnarchiver: AnyObject {
    func decodeObject<T>(forKey key: String, using creator: @escaping ((SafeUnarchiver) throws -> T)) throws -> T
    func decodeObject<T>(forKey key: String, using creator: @escaping ((SafeUnarchiver) throws -> T?)) throws -> T?

    func decodeArray<T>(forKey key: String, using creator: @escaping ((SafeUnarchiver) throws -> T)) throws -> [T]
    func decodeArrayOfOptionals<T>(forKey key: String, using creator: @escaping ((SafeUnarchiver) throws -> T?)) throws -> [T]

    func decodeIfPresent(at key: String) -> Int?
    func decodeIfPresent<T: NSObject>(at key: String) -> T? where T: NSSecureCoding
    func decodeIfPresent<T: _ObjectiveCBridgeable>(at key: String) -> T? where T._ObjectiveCType: NSObject, T._ObjectiveCType: NSSecureCoding

    func decode(at key: String) throws -> Int
    func decode<T: NSObject>(at key: String) throws -> T where T: NSSecureCoding
    func decode<T: _ObjectiveCBridgeable>(at key: String) throws -> T? where T._ObjectiveCType: NSObject, T._ObjectiveCType: NSSecureCoding

}
final class SafeUnarchiverImp: NSKeyedUnarchiver, SafeUnarchiver {

    func decode(at key: String) throws -> Int {
        try NSException.catch {
            self.decodeInteger(forKey: key)
        }
    }

    func decode<T: NSObject>(at key: String) throws -> T where T: NSSecureCoding {
        return try decodeObject(of: T.self, forKey: key) ?? {
            throw self.error!
        }()
    }

    func decode<T: _ObjectiveCBridgeable>(at key: String) throws -> T? where T._ObjectiveCType: NSObject, T._ObjectiveCType: NSSecureCoding {
        guard let obj = decodeObject(of: T._ObjectiveCType.self, forKey: key) else {
            throw self.error!
        }
        return T._unconditionallyBridgeFromObjectiveC(obj)
    }

    public func decodeObject<T>(forKey key: String, using creator: ((SafeUnarchiver) throws -> T)) throws -> T {
        // encoded object name, also allowing coding non-objects
        let className = (T.self as? AnyClass).map(NSStringFromClass) ?? "\(T.self)"
        // collect the creator callback result
        var result: Result<T, Error>?
        let callback = { (coder: NSCoder) in
            do {
                result = .success(try creator(coder as! SafeUnarchiver)) // swiftlint:disable:this force_cast
            } catch {
                result = .failure(error)
            }
        }
        // allow the creator callback to escape to pass it into a Task-local $callback storage
        SafeUnarchiverHelper.withNonescapingCallback(callback) { callback in
            // set Task-local storage
            SafeUnarchiverHelper.$callback.withValue(callback) {
                // highjack the object instantiation with SafeUnarchiverHelper that will call the creator callback
                self.setClass(SafeUnarchiverHelper.self, forClassName: className)
                _=self.decodeObject(of: [SafeUnarchiverHelper.self], forKey: key)
                // cleanup
                self.setClass(nil, forClassName: className)
            }
        }

        return try result?.get() ?? { throw self.error ?? DecodingError.keyNotFound(key.codingKey, .init(codingPath: [key.codingKey], debugDescription: "key not found")) }()
    }

    public func decodeObject<T>(forKey key: String, using creator: ((SafeUnarchiver) throws -> T?)) throws -> T? {
        let className = (T.self as? AnyClass).map(NSStringFromClass) ?? "\(T.self)"
        var result: Result<T?, Error>?
        let callback = { (coder: NSCoder) in
            do {
                result = .success(try creator(coder as! SafeUnarchiver)) // swiftlint:disable:this force_cast
            } catch {
                result = .failure(error)
            }
        }
        SafeUnarchiverHelper.withNonescapingCallback(callback) { callback in
            SafeUnarchiverHelper.$callback.withValue(callback) {
                self.setClass(SafeUnarchiverHelper.self, forClassName: className)
                _=self.decodeObject(of: [SafeUnarchiverHelper.self], forKey: key)
                self.setClass(nil, forClassName: className)
            }
        }
        if let error = self.error {
            throw error
        }
        return try result?.get() ?? { throw self.error ?? DecodingError.keyNotFound(key.codingKey, .init(codingPath: [key.codingKey], debugDescription: "key not found")) }()
    }

    public func decodeArray<T>(forKey key: String, using creator: ((SafeUnarchiver) throws -> T)) throws -> [T] {
        let className = (T.self as? AnyClass).map(NSStringFromClass) ?? "\(T.self)"
        var result: Result<[T], Error>?
        let callback = { (coder: NSCoder) in
            do {
                if case .failure = result { return }
                let item = try creator(coder as! SafeUnarchiver) // swiftlint:disable:this force_cast
                switch result {
                case .none:
                    result = .success([item])
                case .success(var items):
                    items.append(item)
                    result = .success(items)
                case .failure: break
                }
            } catch {
                result = .failure(error)
                self.finishDecoding()
            }
        }
        SafeUnarchiverHelper.withNonescapingCallback(callback) { callback in
            SafeUnarchiverHelper.$callback.withValue(callback) {
                self.setClass(SafeUnarchiverHelper.self, forClassName: className)
                _=self.decodeObject(of: [NSArray.self, SafeUnarchiverHelper.self], forKey: key)
                self.setClass(nil, forClassName: className)
            }
        }
        _=callback
        return try result?.get() ?? { throw self.error ?? DecodingError.keyNotFound(key.codingKey, .init(codingPath: [key.codingKey], debugDescription: "key not found")) }()
    }

    func decodeArrayOfOptionals<T>(forKey key: String, using creator: ((SafeUnarchiver) throws -> T?)) throws -> [T] {
        let className = (T.self as? AnyClass).map(NSStringFromClass) ?? "\(T.self)"
        var result: Result<[T], Error>?
        let callback = { (coder: NSCoder) in
            do {
                if case .failure = result { return }
                guard let item = try creator(coder as! SafeUnarchiver) else { return } // swiftlint:disable:this force_cast
                switch result {
                case .none:
                    result = .success([item])
                case .success(var items):
                    items.append(item)
                    result = .success(items)
                case .failure: break
                }
            } catch {
                result = .failure(error)
                self.finishDecoding()
            }
        }
        SafeUnarchiverHelper.withNonescapingCallback(callback) { callback in
            SafeUnarchiverHelper.$callback.withValue(callback) {
                self.setClass(SafeUnarchiverHelper.self, forClassName: className)
                _=self.decodeObject(of: [NSArray.self, SafeUnarchiverHelper.self], forKey: key)
                self.setClass(nil, forClassName: className)
            }
        }
        _=callback
        return try result?.get() ?? { throw self.error ?? DecodingError.keyNotFound(key.codingKey, .init(codingPath: [key.codingKey], debugDescription: "key not found")) }()
    }

}

extension SafeUnarchiverHelper {

    @TaskLocal static var callback: ((NSCoder) -> Void)?
    public static var supportsSecureCoding: Bool { true }

    @objc func delegatedInitWithCoder(_ coder: NSCoder) {
        Self.callback!(coder)
    }

}
