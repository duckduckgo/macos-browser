//
//  TabNavigations.swift
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

protocol TabNavigationsProtocol: AnyObject, NavigationResponder {
    var expected: NavigationHistory? { get }
    var expectedPublisher: AnyPublisher<NavigationHistory?, Never> { get }
    var mainFrame: NavigationHistory? { get }
    var mainFramePublisher: AnyPublisher<NavigationHistory?, Never> { get }
}

final class TabNavigations: NSObject, TabNavigationsProtocol {

    @Published var expected: NavigationHistory?
    var expectedPublisher: AnyPublisher<NavigationHistory?, Never> {
        $expected.eraseToAnyPublisher()
    }

    @Published var mainFrame: NavigationHistory?
    var mainFramePublisher: AnyPublisher<NavigationHistory?, Never> {
        $mainFrame.eraseToAnyPublisher()
    }

}

extension WebView {

    private var navigations: TabNavigationsProtocol? {
        nil
    }

    var expectedNavigation: NavigationHistory? {
        self.navigations?.expected
    }

    var expectedNavigationPublisher: AnyPublisher<NavigationHistory?, Never>? {
        self.navigations?.expectedPublisher
    }

    var mainFrameNavigation: NavigationHistory? {
        self.navigations?.mainFrame
    }

    var mainFrameNavigationPublisher: AnyPublisher<NavigationHistory?, Never>? {
        self.navigations?.mainFramePublisher
    }

}

extension TabNavigations: NavigationResponder {
    func webView(_ webView: WebView, willRequestNewWebViewFor url: URL, inTargetNamed target: TargetWindowName?, windowFeatures: WindowFeatures?) {
        // TODO: expectedNavigation for non-main-frame?
        if expected == nil {
            expected = []
        }
        expected!.append(.willRequestNewWebView(url: url, target: target, windowFeatures: windowFeatures))
    }

    func webView(_ webView: WebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        // TODO: create if not exist; compare
        expected?.append(.decidePolicyForNavigationAction(navigationAction, preferences: preferences))

        return .allow // this should be the last one
    }

}
