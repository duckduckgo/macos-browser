//
//  FindInPageTabExtension.swift
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

final class FindInPageTabExtension: TabExtension {

    let model: FindInPageModel
    private let userScriptCancellable: AnyCancellable?

    var isVisible: Bool = false

    @MainActor
    init(findInPageScriptPublisher: some Publisher<FindInPageUserScript?, Never>) {
        model = FindInPageModel()
        userScriptCancellable = findInPageScriptPublisher.sink { [weak model] findInPageScript in
            findInPageScript?.model = model
        }
    }

    func show(with webView: WKWebView) {
        model.show(with: webView)
        if !model.text.isEmpty {
            model.find(model.text)
        }
    }

    func close() {
        guard model.isVisible else { return }
        model.findDone()
        model.close()
    }

    func findNext() {
        model.findNext()
    }

    func findPrevious() {
        model.findPrevious()
    }

}

protocol FindInPageProtocol {
    var model: FindInPageModel { get }
    func show(with webView: WKWebView)
    func close()
    func findNext()
    func findPrevious()
}

extension FindInPageTabExtension: FindInPageProtocol {
    func getPublicProtocol() -> FindInPageProtocol { self }
}

extension TabExtensions {
    var findInPage: FindInPageProtocol? {
        resolve(FindInPageTabExtension.self)
    }
}
