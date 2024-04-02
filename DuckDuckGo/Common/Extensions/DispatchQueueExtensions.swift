//
//  DispatchQueueExtensions.swift
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

extension DispatchQueue {

    func dispatch(_ workItem: DispatchWorkItem, sync: Bool) {
        if sync {
            self.sync(execute: workItem)
        } else {
            self.async(execute: workItem)
        }
    }

    /// executes the work item synchronously when running on the main thread, otherwise - schedules asynchronous dispatch
    func asyncOrNow(execute workItem: @escaping @MainActor () -> Void) {
        assert(self == .main)
        if Thread.isMainThread {
            MainActor.assumeIsolated(workItem)
        } else {
            DispatchQueue.main.async {
                workItem()
            }
        }
    }

}

#if swift(<5.10)
private protocol MainActorPerformer {
    func perform<T>(_ operation: @MainActor () throws -> T) rethrows -> T
}
private struct OnMainActor: MainActorPerformer {
    private init() {}
    static func instance() -> MainActorPerformer { OnMainActor() }

    @MainActor(unsafe)
    func perform<T>(_ operation: @MainActor () throws -> T) rethrows -> T {
        try operation()
    }
}
extension MainActor {
    static func assumeIsolated<T>(_ operation: @MainActor () throws -> T) rethrows -> T {
        if #available(macOS 14.0, *) {
            return try assumeIsolated(operation, file: #fileID, line: #line)
        }
        dispatchPrecondition(condition: .onQueue(.main))
        return try OnMainActor.instance().perform(operation)
    }
}
#else
    #warning("This needs to be removed as it‘s no longer necessary.")
#endif
