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
