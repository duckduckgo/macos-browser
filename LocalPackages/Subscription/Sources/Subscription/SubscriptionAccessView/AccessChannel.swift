//
//  AccessChannel.swift
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

public struct AccessChannel: Identifiable, Hashable {
    public var id = UUID()
    public var name: String
    public var image: String
    public var description: String

    public static func activateItems() -> [AccessChannel] {
        [AccessChannel(name: "Apple ID", image: "", description: "Your subscription is automatically available on any device signed in to the same Apple ID."),
         AccessChannel(name: "Email", image: "", description: "Use your email to access your subscription on this device"),
//         AccessChannel(name: "Zzzzz", image: "", description: "Use your email to access your subscription on this device. Use your email to access your subscription on this device. Use your email to access your subscription on this device. Use your email to access your subscription on this device. Use your email to access your subscription on this device. Use your email to access your subscription on this device. "),
         AccessChannel(name: "Sync", image: "", description: "DuckDuckPro is automatically available on your Synced devices. Manage your synced devices in Sync settings.")]
    }
}
