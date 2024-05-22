//
//  Publishers.withLatestFrom.swift
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

import Foundation
import Combine

// More Info:
// - RXMarbles: https://rxmarbles.com/#withLatestFrom
// - https://jasdev.me/notes/with-latest-from
extension Publisher {

    ///  Upon an emission from self, emit the latest value from the
    ///  second publisher, if any exists.
    ///
    ///  - parameter other: A second publisher source.
    ///
    ///  - returns: A publisher containing the latest value from the second publisher, if any.
    func withLatestFrom<Other: Publisher>(
        _ other: Other
    ) -> AnyPublisher<Other.Output, Other.Failure> where Failure == Other.Failure {
        withLatestFrom(other) { _, otherValue in otherValue }
    }

    ///  Merges two publishers into a single publisher by combining each value
    ///  from self with the latest value from the second publisher, if any.
    ///
    ///  - parameter other: A second publisher source.
    ///  - parameter resultSelector: Function to invoke for each value from the self combined
    ///                              with the latest value from the second source, if any.
    ///
    ///  - returns: A publisher containing the result of combining each value of the self
    ///             with the latest value from the second publisher, if any, using the
    ///             specified result selector function.
    func withLatestFrom<Other: Publisher, Result>(
        _ other: Other,
        resultSelector: @escaping (Output, Other.Output) -> Result
    ) -> AnyPublisher<Result, Failure> where Other.Failure == Failure {
        let upstream = share()

        return other
            .map { second in
                upstream.map {
                    resultSelector($0, second)
                }
            }
            .switchToLatest()
            .zip(upstream) // `zip`ping and discarding `\.1` allows for upstream completions to be projected down immediately.
            .map(\.0)
            .eraseToAnyPublisher()
    }

}
