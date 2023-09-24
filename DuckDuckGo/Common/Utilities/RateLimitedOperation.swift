//
//  RateLimitedOperation.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

typealias RateLimitedOperationCompletion = () -> Void

protocol RateLimitedOperation {
    func performRateLimitedOperation(operationName: String, operation: (@escaping RateLimitedOperationCompletion) -> Void)
}

final class UserDefaultsRateLimitedOperation: RateLimitedOperation {

    enum Constants {
        static let userDefaultsPreviewKey = "rate-limited-operation.last-operation-timestamp"
    }

    private let minimumTimeSinceLastOperation: TimeInterval
    private let userDefaults: UserDefaults

    convenience init(debug: TimeInterval, release: TimeInterval) {
        #if DEBUG || REVIEW
        self.init(minimumTimeSinceLastOperation: debug)
        #else
        self.init(minimumTimeSinceLastOperation: release)
        #endif
    }

    init(minimumTimeSinceLastOperation: TimeInterval, userDefaults: UserDefaults = .standard) {
        self.minimumTimeSinceLastOperation = minimumTimeSinceLastOperation
        self.userDefaults = userDefaults
    }

    // MARK: - RateLimitedOperation

    func performRateLimitedOperation(operationName: String, operation: (@escaping RateLimitedOperationCompletion) -> Void) {
        // First, check whether there is an existing last refresh date and if it's greater than the current date when adding the minimum refresh time.
        if let lastRefreshDate = lastRefreshDate(forOperationName: operationName),
           lastRefreshDate.addingTimeInterval(minimumTimeSinceLastOperation) > Date() {
            return
        }

        operation {
            self.updateLastRefreshDate(forOperationName: operationName)
        }
    }

    private func lastRefreshDate(forOperationName operationName: String) -> Date? {
        let key = userDefaultsKey(operationName: operationName)

        guard let object = userDefaults.object(forKey: key) else {
            return nil
        }

        guard let date = object as? Date else {
            assertionFailure("Got rate limited date, but couldn't convert it to Date")
            return nil
        }

        return date
    }

    private func updateLastRefreshDate(forOperationName operationName: String) {
        let key = userDefaultsKey(operationName: operationName)
        userDefaults.setValue(Date(), forKey: key)
    }

    private func userDefaultsKey(operationName: String) -> String {
        return "\(Constants.userDefaultsPreviewKey).\(operationName)"
    }

}
