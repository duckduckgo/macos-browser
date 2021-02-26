//
//  DataTaskProviding.swift
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
import Combine

/// A testable abstraction of a data task publisher, which you can usually get from URLSession.dataTaskPublisher(for: )
protocol DataTaskProviding {

    func dataTaskPublisher(for: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), URLError>

}

/// Default implementation which just delegates to URLSession.shared
struct SharedURLSessionDataTaskProvider: DataTaskProviding {

    func dataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), URLError> {
        return URLSession.shared.dataTaskPublisher(for: request)
            .eraseToAnyPublisher()
    }

}
