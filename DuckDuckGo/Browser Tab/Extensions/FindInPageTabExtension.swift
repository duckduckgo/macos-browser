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

final class FindInPageTabExtension {

    private var userScriptCancellable: AnyCancellable?

    fileprivate var model: FindInPageModel? {
        didSet {
            attachFindInPage()
        }
    }
    private weak var findInPageScript: FindInPageUserScript? {
        didSet {
            attachFindInPage()
        }
    }

    init(findInPageScriptPublisher: some Publisher<FindInPageUserScript?, Never>) {
        userScriptCancellable = findInPageScriptPublisher.sink { [weak self] findInPageScript in
            self?.findInPageScript = findInPageScript
        }
    }

    private func attachFindInPage() {
        findInPageScript?.model = model
    }

}

extension Tab {

    func openFindInPage(with model: FindInPageModel) {
        extensions.findInPage?.model = model
    }

    func findDone() {
        extensions.findInPage?.model?.findDone()
    }

    func findNext() {
        extensions.findInPage?.model?.findNext()
    }

    func findPrevious() {
        extensions.findInPage?.model?.findPrevious()
    }

}

extension TabExtensions {

    var findInPage: FindInPageTabExtension? {
        resolve()
    }

}

extension FindInPageTabExtension: TabExtension {
    static func make(owner tab: Tab) -> FindInPageTabExtension {
        FindInPageTabExtension(findInPageScriptPublisher: tab.findInPageScriptPublisher)
    }
}

private extension Tab {

    var findInPageScriptPublisher: some Publisher<FindInPageUserScript?, Never> {
        userScriptsPublisher.compactMap { $0?.findInPageScript }
    }

}
