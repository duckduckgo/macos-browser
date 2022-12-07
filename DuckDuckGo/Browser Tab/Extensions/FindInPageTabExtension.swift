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

    private var findInPageCancellable: AnyCancellable?
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

    private func subscribeToFindInPageTextChange() {
        findInPageCancellable = model?.$text.receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.find(text)
            }
    }

    private func attachFindInPage() {
        findInPageScript?.model = model
        subscribeToFindInPageTextChange()
    }

    private func find(_ text: String) {
        guard let webView = model?.webView else { return }
        findInPageScript?.find(text, in: webView)
    }

}

extension Tab {

    func openFindInPage(with model: FindInPageModel) {
        extensions.findInPage?.model = model
    }

    func findDone() {
        userScripts?.findInPageScript.findDone(in: self.webView)
    }

    func findNext() {
        userScripts?.findInPageScript.findNext(in: self.webView)
    }

    func findPrevious() {
        userScripts?.findInPageScript.findPrevious(in: self.webView)
    }

}

extension TabExtensions {

    var findInPage: FindInPageTabExtension? {
        resolve()
    }

}

extension FindInPageTabExtension: TabExtension {
    final class ResolvingHelper: TabExtensionResolvingHelper {
        static func make(owner tab: Tab) -> FindInPageTabExtension {
            FindInPageTabExtension(findInPageScriptPublisher: tab.findInPageScriptPublisher)
        }
    }
}

private extension Tab {

    var findInPageScriptPublisher: some Publisher<FindInPageUserScript?, Never> {
        userScriptsPublisher.compactMap { $0?.findInPageScript }
    }

}
