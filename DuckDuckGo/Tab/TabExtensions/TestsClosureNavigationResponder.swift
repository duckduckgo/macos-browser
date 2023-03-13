//
//  TestsClosureNavigationResponder.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Foundation
import Navigation

#if DEBUG

final class TestsClosureNavigationResponderTabExtension: TabExtension {

    let responder: ClosureNavigationResponder

    init(_ responder: ClosureNavigationResponder) {
        self.responder = responder
    }

}

protocol TestsClosureNavigationResponderTabExtensionProtocol {
    var responder: ClosureNavigationResponder { get }
}

extension TestsClosureNavigationResponderTabExtension: TestsClosureNavigationResponderTabExtensionProtocol {
    func getPublicProtocol() -> TestsClosureNavigationResponderTabExtensionProtocol { self }
}

private extension TabExtensions {
    var testsClosureNavigationResponderTabExtension: TestsClosureNavigationResponderTabExtensionProtocol? {
        resolve(TestsClosureNavigationResponderTabExtension.self, .nullable)
    }
}

#endif

extension Tab {
#if DEBUG
    var testsClosureNavigationResponder: ClosureNavigationResponder? {
        self.testsClosureNavigationResponderTabExtension?.responder
    }
#else
    var testsClosureNavigationResponder: ClosureNavigationResponder? { nil }
#endif
}
