//
//  FutureExtension.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import Combine

extension Future {

    func get() async throws -> Output {
        if #available(macOS 12.0, *) {
            return try await self.value
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                self.receive { result in
                    continuation.resume(with: result)
                }
            }
        }
    }

    func receive(completionHandler: @escaping (Result<Output, Failure>) -> Void) {
        var cancellable: AnyCancellable?
        cancellable = self.sink { completion in
            withExtendedLifetime(cancellable) {
                if case .failure(let error) = completion {
                    completionHandler(.failure(error))
                }
                cancellable = nil
            }
        } receiveValue: { output in
            completionHandler(.success(output))
        }
    }

}

extension Future where Failure == Never {

    static func promise() -> (future: Future<Output, Never>, fulfill: (Output) -> Void) {
        var fulfill: ((Result<Output, Never>) -> Void)!
        let future = Future<Output, Never> { fulfill = $0 }
        assert(fulfill != nil)
        return (future, { fulfill(.success($0)) })
    }

}

extension Publishers.First {

    func promise() -> Future<Output, Failure> {
        return Future { fulfill in
            var cancellable: AnyCancellable?
            cancellable = self.sink { completion in
                withExtendedLifetime(cancellable) {
                    if case .failure(let error) = completion {
                        fulfill(.failure(error))
                    }
                    cancellable = nil
                }
            } receiveValue: { output in
                fulfill(.success(output))
            }
        }
    }

}
