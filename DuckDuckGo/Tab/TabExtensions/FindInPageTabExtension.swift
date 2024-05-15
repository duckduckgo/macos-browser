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
import Navigation
import UniformTypeIdentifiers

final class FindInPageTabExtension: TabExtension {

    let model = FindInPageModel()
    private weak var webView: WebView?
    private var cancellable: AnyCancellable?

    private(set) var isActive = false
    private var isPdf = false

    private enum Constants {
        static let maxMatches: UInt = 1000
    }

    @MainActor
    func show(with webView: WebView) {
        self.webView = webView

        if cancellable == nil {
            cancellable = model.$text
                .dropFirst()
                .debounce(for: 0.2, scheduler: RunLoop.main)
                .scan((old: "", new: model.text)) { ($0.new, $1) }
                .sink { [weak self] change in
                    Task { @MainActor in
                        await self?.textDidChange(from: change.old, to: change.new)
                    }
                }
        }

        Task { @MainActor in
            await showFindInPage()
        }
    }

    @MainActor
    private func showFindInPage() async {
        let alreadyVisible = model.isVisible
        // makes Find In Page a first responder if re-requested
        model.show()

        guard !alreadyVisible else {
            // Find In Page is already active
            guard !model.text.isEmpty,
                  // would just find next for PDF
                  !isPdf else { return }

            // re-highlight the same result when Find In Page is already active
            await find(model.text, with: [.noIndexChange, .determineMatchIndex, .showOverlay])
            return
        }

        await reset()
        guard !model.text.isEmpty else { return }

        await find(model.text, with: .showOverlay)
        await doItOneMoreTimeForPdf(with: model.text)
    }

    /// clear Find In Page state
    @MainActor
    private func reset() async {
        model.update(currentSelection: nil, matchesFound: nil)
        isActive = false

        // hide overlay and reset matchIndex
        webView?.clearFindInPageState()
        try? await webView?.deselectAll()
        self.isPdf = (await webView?.mimeType == UTType.pdf.preferredMIMEType)
    }

    @MainActor
    private func textDidChange(from oldValue: String, to string: String) async {
        guard !string.isEmpty else {
            await reset()
            return
        }

        var options = _WKFindOptions.showOverlay

        if isActive {
            // continue search from current matched result
            options.insert(.noIndexChange)
        }

        await find(string, with: options)
        await doItOneMoreTimeForPdf(with: string, oldValue: oldValue)
    }

    /// PDF would find the first match 2 times, the ghosty result won‘t be there when going round
    /// same is actual for Safari (but not the Preview.app)
    @MainActor
    private func doItOneMoreTimeForPdf(with string: String, options: _WKFindOptions = .noIndexChange, oldValue: String? = nil) async {
        guard isPdf, oldValue != string else { return }
        // hit me webvie one more time ¯\_(ツ)_/¯
        await find(string, with: options)
    }

    @MainActor
    private func find(_ string: String, with options: _WKFindOptions = []) async {
        guard !string.isEmpty else {
            await reset()
            return
        }

        // reset text selection to the selection start so Find In Page finds the same result
        if options.contains(.noIndexChange) {
            try? await webView?.collapsSelectionToStart()
        }

        var options = options.union([.caseInsensitive, .wrapAround, .showFindIndicator])
        if !self.isActive {
            options.remove(.showOverlay)
        }

        let result = await webView?.find(string, with: options, maxCount: Constants.maxMatches)

        switch result {
        case .found(matches: let matchesFound):
            self.model.update(currentSelection: calculateCurrentIndex(with: options, matchesFound: matchesFound ?? 1),
                              matchesFound: matchesFound)

            // first search _sometimes_ won‘t highlight the first match
            // search again to ensure highlighting with noIndexChange to find the same match
            if !self.isActive {
                self.isActive = true

                // don‘t apply for cmd+[shift]+g search when Find In Page is hidden
                guard self.model.isVisible,
                      !isPdf else { break }

                webView?.clearFindInPageState()
                await find(string, with: [.noIndexChange, .showOverlay])
            }

        case .notFound:
            self.webView?.clearFindInPageState()
            self.isActive = false
            self.model.update(currentSelection: 0, matchesFound: 0)

        case .cancelled, .none:
            break
        }
    }

    private func calculateCurrentIndex(with options: _WKFindOptions, matchesFound: UInt) -> UInt {
        // indeed it will keep the same index > 1 for a shortened search term even if it's became the first search result
        // the same is actual for Safari
        guard let currentIndex = model.currentSelection else { return 1 }

        if options.contains(.noIndexChange) {
            // keeping current result index
            return currentIndex

        } else if options.contains(.backwards) {
            // searching backwards
            return currentIndex > 1 ? currentIndex - 1 : matchesFound

        } else if currentIndex < matchesFound {
            // searching forward
            return currentIndex + 1
        }
        return 1
    }

    func close() {
        guard model.isVisible else { return }
        model.close()
        cancellable = nil
        webView?.clearFindInPageState()
        isActive = false
    }

    func findNext() {
        guard !model.text.isEmpty else { return }
        Task { @MainActor [isActive /* copy value before search */] in
            await find(model.text, with: model.isVisible ? .showOverlay : [])

            // pdf would reset search index for cmd+g, at least fix the doubling search result here
            await doItOneMoreTimeForPdf(with: model.text, oldValue: (isActive ? model.text : ""))
        }
    }

    func findPrevious() {
        guard !model.text.isEmpty else { return }
        Task { @MainActor in
            await find(model.text, with: model.isVisible ? [.showOverlay, .backwards] : [.backwards])
        }
    }

}

extension FindInPageTabExtension: NavigationResponder {

    func didStart(_ navigation: Navigation) {
        close()
    }

    func navigation(_ navigation: Navigation, didSameDocumentNavigationOf navigationType: WKSameDocumentNavigationType) {
        if [.sessionStatePush, .sessionStatePop].contains(navigationType) {
            close()
        }
    }

}

protocol FindInPageProtocol: AnyObject, NavigationResponder {
    var model: FindInPageModel { get }
    var isActive: Bool { get }

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
