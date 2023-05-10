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

    let model = FindInPageModel()
    private weak var webView: WebView?
    private var cancellable: AnyCancellable?

    private var isFindInPageActive = false

    private enum Constants {
        static let randomString = UUID().uuidString
        static let maxMatches: UInt = 1000
    }

    func show(with webView: WebView) {
        self.webView = webView

        model.show()
        model.update(currentSelection: nil, matchesFound: nil)

        reset { [weak self] in
            guard let self, !self.model.text.isEmpty else { return }
            self.find(self.model.text)
        }

        cancellable = model.$text
            .dropFirst()
            .debounce(for: 0.2, scheduler: RunLoop.main)
            .sink { [weak self] text in
                self?.textDidChange(to: text)
            }
    }

    private func reset(completionHandler: (() -> Void)? = nil) {
        model.update(currentSelection: nil, matchesFound: nil)
        isFindInPageActive = false

        // hide overlay and reset matchIndex
        webView?.clearFindInPageState()
        // search for deliberately missing string to reset current match
        webView?.find(Constants.randomString, with: [], maxCount: Constants.maxMatches) { _ in
            completionHandler?()
        }
    }

    private func textDidChange(to string: String) {
        if string.isEmpty {
            reset()
        } else {
            var options: _WKFindOptions = [.showOverlay]
            if isFindInPageActive {
                options.insert(.noIndexChange) // continue search from current match index
            }
            find(string, with: options)
        }
    }

    private func find(_ string: String, with options: _WKFindOptions = []) {
        guard !string.isEmpty else { return }

        let options = options.union([.caseInsensitive, .wrapAround, .showFindIndicator, .determineMatchIndex])
        webView?.find(string, with: options, maxCount: Constants.maxMatches) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let result):
                self.model.update(currentSelection: result.matchIndex.map { $0 + 1 }, matchesFound: result.matchesFound)

                // first search _sometimes_ won‘t highlight the first match
                // search again with explicit parameters and noIndexChange to ensure highlighting
                if !self.isFindInPageActive,
                    self.model.isVisible,
                    result.string == self.model.text {

                    self.isFindInPageActive = true
                    self.find(string, with: [.noIndexChange, .showOverlay])
                }

            case .failure(.notFound):
                self.webView?.clearFindInPageState()
                self.isFindInPageActive = false
                self.model.update(currentSelection: 0, matchesFound: 0)
            case .failure(.cancelled):
                break
            }
        }
    }

    func close() {
        guard model.isVisible else { return }
        model.close()
        cancellable = nil
        webView?.clearFindInPageState()
    }

    func findNext() {
        guard !model.text.isEmpty else { return }
        find(model.text, with: model.isVisible ? .showOverlay : [])
    }

    func findPrevious() {
        guard !model.text.isEmpty else { return }
        find(model.text, with: model.isVisible ? [.showOverlay, .backwards] : [.backwards])
    }

}

protocol FindInPageProtocol {
    var model: FindInPageModel { get }
    func show(with webView: WebView)
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
