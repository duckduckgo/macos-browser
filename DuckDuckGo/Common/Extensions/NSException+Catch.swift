//
//  NSException+Catch.swift
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

extension NSException {

    final class Error: NSError, LocalizedError {

        init(exception: NSException) {
            super.init(domain: exception.name.rawValue, code: -1, userInfo: [
                "NSException": exception,
                NSLocalizedDescriptionKey: exception.description,
                NSDebugDescriptionErrorKey: exception.debugDescription,
                NSLocalizedFailureReasonErrorKey: exception.reason ?? ""
            ])

        }
        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }
    }

    static func `catch`<T>(_ closure: () throws -> T) throws -> T {
        var result: Result<T, Swift.Error>?
        let exception = self.try {
            do {
                result = .success(try closure())
            } catch {
                result = .failure(error)
            }
        }
        if case .success(let value) = result {
            return value
        } else if case .failure(let error) = result {
            throw error
        } else if let exception = exception {
            throw Error(exception: exception)
        } else {
            fatalError("NSException.catch: invalid flow")
        }
    }

}
