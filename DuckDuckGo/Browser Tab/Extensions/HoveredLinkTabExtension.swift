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

final class HoveredLinkTabExtension {

    private var userScriptsCancellable: AnyCancellable?
    fileprivate var hoveredLinkSubject = PassthroughSubject<URL?, Never>()

    init(tab: Tab) {
        userScriptsCancellable = tab.userScriptsPublisher.sink { [weak self] userScripts in
            userScripts?.hoverUserScript.delegate = self
        }
    }

}

extension HoveredLinkTabExtension: HoverUserScriptDelegate {

    func hoverUserScript(_ script: HoverUserScript, didChange url: URL?) {
        hoveredLinkSubject.send(url)
    }

}

extension Tab {

    var hoveredLinkPublisher: AnyPublisher<URL?, Never> {
        extensions.hoveredLinks?.hoveredLinkSubject.eraseToAnyPublisher() ?? Just(nil).eraseToAnyPublisher()
    }

}
