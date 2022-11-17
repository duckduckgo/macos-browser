//
//  TabExtensionsTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class TabExtensionsTests: XCTestCase {

//    override func setUp() {
//        TestsDependencyProvider<Tab>.setUp {
//            $0.faviconManagement = FaviconManagerMock()
//            $0.useDefault(for: \.privatePlayer)
//            $0.useDefault(for: \.windowControllersManager)
//        }
//    }
//
//    override func tearDown() {
//        TestsDependencyProvider<Tab>.reset()
//    }

    func testDynamicExtensionsBuilder() {
        struct Extension1: TabExtension {
            var value1 = "string"
            let tab: UnsafePointer<Tab>
            init(tab: Tab) {
                self.tab = withUnsafePointer(to: tab) { $0 }
            }
        }
        class Extension2: TabExtension {
            var value2: String { "string 2" }
            weak var tab: Tab?
            required init(tab: Tab) {
                self.tab = tab
            }
        }
        class Extension3: Extension2 {
            override var value2: String { "overriden" }
            var value3 = "string 3"
        }
//        struct TestExtBuilder: ExtensionsBuilder {
//
//            func buildExtensions(for tab: Tab) -> DynamicTabExtensions {
//                var result = DynamicTabExtensions()
//                result.printing
//                return result
//            }
//
//        }

//        TestsDependencyProvider<Tab>.shared.extensionsBuilder = TabExtensionsBuilder()

//        struct TestTabExtensions: ExtensionsProvider {
//            let extension1 = Extension1.self
//            let extension2 = Extension2.self
//        }
//        DynamicExtensionsBuilder<TestTabExtensions>().buildExtensions(for: Tab())

//        let tab = Tab()
//        let builtExtensions = (tab.extensions as? DynamicTabExtensions)!
//        XCTAssertEqual(, <#T##expression2: Equatable##Equatable#>)
    }

}
