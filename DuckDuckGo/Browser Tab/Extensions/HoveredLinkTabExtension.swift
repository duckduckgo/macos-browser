//
//  HoveredLinkTabExtension.swift
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

final class HoveredLinkTabExtension: TabExtension {

    private var cancellable: AnyCancellable?
    fileprivate var hoveredLinkSubject = PassthroughSubject<URL?, Never>()

    init(hoverUserScriptPublisher: some Publisher<HoverUserScript?, Never>) {
        cancellable = hoverUserScriptPublisher.sink { [weak self] hoverUserScript in
            hoverUserScript?.delegate = self
        }
    }

}

extension HoveredLinkTabExtension: HoverUserScriptDelegate {
    func hoverUserScript(_ script: HoverUserScript, didChange url: URL?) {
        hoveredLinkSubject.send(url)
    }
}

protocol HoveredLinksProtocol {
    var hoveredLinkPublisher: AnyPublisher<URL?, Never> { get }
}

extension HoveredLinkTabExtension: HoveredLinksProtocol {
    func getPublicProtocol() -> HoveredLinksProtocol { self }

    var hoveredLinkPublisher: AnyPublisher<URL?, Never> {
        hoveredLinkSubject.eraseToAnyPublisher()
    }
}

extension TabExtensions {
    var hoveredLinks: HoveredLinksProtocol? {
        resolve(HoveredLinkTabExtension.self)
    }
}

extension Tab {
    var hoveredLinkPublisher: AnyPublisher<URL?, Never> {
        self.hoveredLinks?.hoveredLinkPublisher ?? Just(nil).eraseToAnyPublisher()
    }
}
