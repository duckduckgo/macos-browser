//
//  main.swift
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
import Swifter

/**

 tests-server used for Integration Tests HTTP requests mocking

 run as a Pre-action for Test targets (target -> Edit scheme.. -> Test -> Pre-actions/Post-actions)
 - current work directory: Integration Tests Resources directory, used for file lookup for requests without `data` parameter

 see TestURLExtension.swift for usage example

 **/

let server = HttpServer()

// swiftlint:disable:next opening_brace
server.middleware = [{ request in
    let params = request.queryParams.reduce(into: [:]) { $0[$1.0] = $1.1.removingPercentEncoding }
    print(request.method, request.path, params)
    defer {
        print("\n")
    }

    let status = params["status"].flatMap(Int.init) ?? 200
    let reason = params["reason"] ?? "OK"

    let data: Data
    if request.path == "/", params["data"] == nil {
        data = Data()

    } else if let str = params["data"] {
        data = Data(base64Encoded: str) ?? str.data(using: .utf8)!

    } else {
        let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resourceURL = currentDirectoryURL.appendingPathComponent(request.path)
        do {
            data = try Data(contentsOf: resourceURL)
        } catch {
            print("file not found at", resourceURL.path)
            return .notFound
        }
    }

    let headers: [String: String]
    if let headersQuery = params["headers"] {
        guard let url = URL(string: "/?" + headersQuery),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            print(headersQuery + " is not a valid URL query string")
            return .badRequest(.text(headersQuery + " is not a valid URL query string"))
        }

        headers = components.queryItems?.reduce(into: [:]) { $0[$1.name] = $1.value } ?? [:]
    } else {
        headers = [:]
    }

    return .raw(status, reason, headers) { writer in
        try? writer.write(data)
    }
}]

print("starting web server at localhost:8085")
try server.start(8085)

RunLoop.main.run()
