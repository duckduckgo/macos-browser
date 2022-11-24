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

    private weak var tab: Tab?
    private var findInPageCancellable: AnyCancellable?
    private var userScriptsCancellable: AnyCancellable?

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

    init(tab: Tab) {
        self.tab = tab
        userScriptsCancellable = tab.userScriptsPublisher.sink { [weak self] userScripts in
            self?.findInPageScript = userScripts?.findInPageScript
        }
    }

    private func subscribeToFindInPageTextChange() {
        findInPageCancellable = model?.$text.receive(on: DispatchQueue.main).sink { [weak self] text in
            self?.find(text: text)
        }
    }

    private func attachFindInPage() {
        findInPageScript?.model = model
        subscribeToFindInPageTextChange()
    }

    private func find(text: String) {
        guard let webView = tab?.webView else { return }
        findInPageScript?.find(text: text, inWebView: webView)
    }

}

extension Tab {

    func openFindInPage(with model: FindInPageModel) {
        extensions.findInPage?.model = model
    }

    func findDone() {
        userScripts?.findInPageScript.done(withWebView: self.webView)
    }

    func findNext() {
        userScripts?.findInPageScript.next(withWebView: self.webView)
    }

    func findPrevious() {
        userScripts?.findInPageScript.previous(withWebView: self.webView)
    }

}
