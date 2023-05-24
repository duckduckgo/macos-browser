//
//  UserDialogRequest.swift
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
import Foundation

enum UserDialogRequestError: Error {
    case deinitialized

}
protocol UserDialogRequestProtocol: AnyObject {
    associatedtype Info
    associatedtype Output

    func addCompletionHandler(_ completionHandler: @escaping (Result<Void, UserDialogRequestError>) -> Void)
}
typealias AnyUserDialogRequest = any UserDialogRequestProtocol

/// Used as a generic interactive dialog presentation model with a guaranteed callback on deinit with a .failure(.deinitialized) result
final class UserDialogRequest<Info, Output>: UserDialogRequestProtocol {

    typealias Failure = UserDialogRequestError
    typealias CallbackResult = Swift.Result<Output, Failure>
    typealias Callback = (CallbackResult) -> Void

    var parameters: Info

    private var callback: Callback?

    var isComplete: Bool {
        callback == nil
    }

    init(_ parameters: Info, callback: @escaping Callback) {
        self.parameters = parameters
        self.callback = callback
    }

    private init(_ parameters: Info) {
        self.parameters = parameters
        self.callback = nil
    }

    static func future(with parameters: Info) -> (request: UserDialogRequest, future: Future<Output, Failure>) {
        let request = self.init(parameters)
        let future = Future { promise in
            request.callback = promise
        }
        return (request, future)
    }

    private func getDecisionHandlerOnce() -> Callback? {
        var handler: Callback?
        swap(&handler, &callback) // only run once
        return handler
    }

    func submit(_ result: Output) {
        getDecisionHandlerOnce()?(.success(result))
    }

    func addCompletionHandler(_ completionHandler: @escaping (Swift.Result<Void, Failure>) -> Void) {
        guard let callback /* isComplete == false */ else {
            assertionFailure("The dialog was already completed")
            completionHandler(.failure(.deinitialized))
            return
        }
        self.callback = { [callback] result in
            callback(result)
            completionHandler(result.map { _ in () })
        }
    }

    deinit {
        guard let callback else { return }

        DispatchQueue.main.async {
            callback(.failure(.deinitialized))
        }
    }

}

extension UserDialogRequest where Info == Void {

    convenience init(callback: @escaping Callback) {
        self.init((), callback: callback)
    }

}

extension UserDialogRequest where Output == Void {

    convenience init(_ parameters: Info) {
        self.init(parameters, callback: { _ in })
    }

    func submit() {
        submit( () )
    }

}

extension UserDialogRequest where Info == Void, Output == Void {

    convenience init() {
        self.init((), callback: { _ in })
    }

}
