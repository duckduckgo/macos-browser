//
//  SandboxTestToolNotifications.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

enum SandboxTestNotification: String {
    case hello = "sandbox_test_tool_hello"
    case ping = "sandbox_test_tool_ping"
    case pong = "sandbox_test_tool_pong"

    case openFile = "sandbox_test_tool_open_file"
    case openFileWithoutBookmark = "sandbox_test_tool_open_file_no_bookmark"
    case fileRead = "sandbox_test_tool_open_file_read"

    case error = "sandbox_test_tool_error"
    case terminate = "sandbox_test_tool_term"

    case openBookmarkWithFilePresenter = "sandbox_test_tool_open_bookmark_with_file_presenter"
    case closeFilePresenter = "sandbox_test_tool_close_file_presenter"

    case fileMoved = "sandbox_test_tool_file_presenter_file_moved"
    case fileBookmarkDataUpdated = "sandbox_test_tool_file_presenter_bookmark_data_updated"

    case stopAccessingSecurityScopedResourceCalled = "sandbox_test_tool_stop_accessing_security_scoped_resource"

    var name: Notification.Name {
        .init(rawValue: rawValue)
    }

    public static func == (a: SandboxTestNotification, b: Notification.Name) -> Bool {
        a.rawValue == b.rawValue
    }

    public static func == (a: Notification.Name, b: SandboxTestNotification) -> Bool {
        a.rawValue == b.rawValue
    }
}

enum UserInfoKeys {
    static let errorDescription = "descr"
    static let errorDomain = "domain"
    static let errorCode = "code"
}
