//
//  ExpectedNavigationExtension.swift
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
import Navigation

struct DidCancelError: Error {
    let expectedNavigations: [ExpectedNavigation]?
}
struct DidBecomeDownload: Error {
    let download: WebKitDownload
}

extension NavigationProtocol {

    @MainActor
    var result: Result<Void, Error> {
        get async {
            do {
                try await withCheckedThrowingContinuation { continuation in
                    self.appendResponder(didCancel: { _, expectedNavigations in
                        continuation.resume(throwing: DidCancelError(expectedNavigations: expectedNavigations))
                    }, navigationDidFinish: { _ in
                        continuation.resume()
                    }, navigationDidFail: { _, error in
                        continuation.resume(throwing: error)
                    }, navigationActionDidBecomeDownload: { _, download in
                        continuation.resume(throwing: DidBecomeDownload(download: download))
                    })
                }
                return .success( () )
            } catch {
                return .failure(error)
            }
        }
    }

}
