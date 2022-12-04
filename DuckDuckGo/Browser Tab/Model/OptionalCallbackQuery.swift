//
//  OptionalCallbackQuery.swift
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

import Foundation

enum OptionalCallbackQueryError: Error {
    case cancelled
    case deinitialized

}
protocol OptionalCallbackQueryProtocol: AnyObject {
    associatedtype Info
    associatedtype Output

    func addCompletionHandler(_ completionHandler: @escaping (Result<Void, OptionalCallbackQueryError>) -> Void)
    func cancel()
}
typealias AnyOptionalCallbackQuery = any OptionalCallbackQueryProtocol

final class OptionalCallbackQuery<Info, Output>: OptionalCallbackQueryProtocol {

    typealias Result = Swift.Result<Output, Failure>
    typealias Failure = OptionalCallbackQueryError

    var parameters: Info
    typealias DecisionHandler = (Result) -> Void
    private var decisionHandler: DecisionHandler?

    var isComplete: Bool {
        decisionHandler == nil
    }

    init(_ parameters: Info, decisionHandler: @escaping DecisionHandler) {
        self.parameters = parameters
        self.decisionHandler = decisionHandler
    }

    private func getDecisionHandlerOnce() -> DecisionHandler? {
        var handler: DecisionHandler?
        swap(&handler, &decisionHandler) // only run once
        return handler
    }

    func submit(_ result: Output) {
        getDecisionHandlerOnce()?(.success(result))
    }

    func cancel() {
        decisionHandler?(.failure(.cancelled))
    }

    func addDecisionHandler(_ newDecisionHandler: @escaping DecisionHandler) {
        self.decisionHandler = { [decisionHandler] result in
            decisionHandler?(result)
            newDecisionHandler(result)
        }
    }

    func addCompletionHandler(_ completionHandler: @escaping (Swift.Result<Void, Failure>) -> Void) {
        self.decisionHandler = { [decisionHandler] result in
            decisionHandler?(result)
            completionHandler(result.map { _ in () })
        }
    }

    deinit {
        decisionHandler?(.failure(.deinitialized))
    }

}

extension OptionalCallbackQuery where Info == Void {

    convenience init(decisionHandler: @escaping DecisionHandler) {
        self.init((), decisionHandler: decisionHandler)
    }
    
}

extension OptionalCallbackQuery where Output == Void {

    convenience init(_ parameters: Info) {
        self.init(parameters, decisionHandler: { _ in })
    }

    func submit() {
        submit( () )
    }

}

extension OptionalCallbackQuery where Info == Void, Output == Void {

    convenience init() {
        self.init((), decisionHandler: { _ in })
    }

}
