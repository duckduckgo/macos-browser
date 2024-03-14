//
//  SandboxTestTool.swift
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

import AppKit
import Foundation
import ArgumentParser

@main
struct SandboxTestTool: ParsableCommand {
    @Option(help: ArgumentHelp(""))
    var file: String?

    mutating func run() throws {
        _=NSApplication.shared

        let c = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.ping).sink { n in
            DistributedNotificationCenter.default().post(name: SandboxTestNotification.ack, object: n.object as? String)
        }
        DistributedNotificationCenter.default().post(name: SandboxTestNotification.hello, object: file)

//        let pics = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0].lastPathComponent
//        let home = URL.nonSandboxHomeDirectory
//        let protectedDir = home.appendingPathComponent(pics)
//        print(try Data(contentsOf: protectedDir.appendingPathComponent("hi")))

        NSApp.run()
        withExtendedLifetime(c) {}
    }

}
