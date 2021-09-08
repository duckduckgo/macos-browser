//
//  RunLoopExtension.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

extension RunLoop {

    func wait(for dispatchGroup: DispatchGroup) {
        assert(self === RunLoop.main)

        let port = Port()
        RunLoop.current.add(port, forMode: .default)

        var notified = false
        dispatchGroup.notify(queue: .main) {
            notified = true

            let sendPort = Port()
            RunLoop.current.add(sendPort, forMode: .default)
            sendPort.send(before: Date(), components: nil, from: port, reserved: 0)
            RunLoop.current.remove(sendPort, forMode: .default)
        }

        while !notified {
            RunLoop.current.run(mode: .default, before: .distantFuture)
        }

        RunLoop.current.remove(port, forMode: .default)
    }

}
