//
//  InstantAnswersProvider.swift
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
import SwiftSoup

struct InstantAnswers: Equatable, Decodable {
    enum CodingKeys: String, CodingKey {
        case relatedTopics = "RelatedTopics"
    }
    let relatedTopics: [Either<InstantAnswer, SeeAlsoInstantAnswers>]
}
struct InstantAnswer: Equatable, Decodable {
    enum CodingKeys: String, CodingKey {
        case url = "FirstURL"
        case icon = "Icon"
        case result = "Result"
        case text = "Text"
    }

    let url: URL
    let icon: InstantAnswerIcon
    let result: String
    let text: String
}
struct SeeAlsoInstantAnswers: Equatable, Decodable {
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case topics = "Topics"
    }
    let name: String
    let topics: [InstantAnswer]
}
enum Either<A, B> {
    case a(A)
    case b(B)
}
extension Either: Decodable where A: Decodable, B: Decodable {
    init(from decoder: Decoder) throws {
        do {
            self = .a(try A.self(from: decoder))
        } catch {
            self = .b(try B.self(from: decoder))
        }
    }
}
extension Either: Equatable where A: Equatable, B: Equatable {

}
struct InstantAnswerIcon: Equatable, Decodable {
    enum CodingKeys: String, CodingKey {
        case height = "Height"
        case url = "URL"
        case width = "Width"
    }

    let url: String
    let height: Either<Int, String>?
    let width: Either<Int, String>?
}

final class InstantAnswersProvider {
    static let shared = InstantAnswersProvider()

    func queryInstantAnswers(for searchQuery: String) -> AnyPublisher<[InstantAnswer], Error> {
        let url = URL.makeInstantAnswersURL(from: searchQuery)!
        let request = URLRequest(url: url)

        return SharedURLSessionDataTaskProvider()
            .dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: InstantAnswers.self, decoder: JSONDecoder())
            .mapError {
                print($0)
                return $0
            }.map {
                $0.relatedTopics.reduce(into: [InstantAnswer]()) {
                    switch $1 {
                    case .a(let answer):
                        $0.append(answer)
                    case .b(let seeAlso):
                        $0.append(contentsOf: seeAlso.topics)
                    }
                }
            }
            .eraseToAnyPublisher()
    }

}
