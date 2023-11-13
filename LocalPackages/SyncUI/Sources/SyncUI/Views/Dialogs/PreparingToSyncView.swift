//
//  PreparingToSyncView.swift
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

import SwiftUI

public struct PreparingToSyncView: View {

    public init() {}

    public var body: some View {
        SyncDialog(spacing: 20.0, bottomText: "Connecting…") {
            VStack(alignment: .center, spacing: 20) {
                Image("Sync-96")
                Text("Prepating to Sync")
                    .font(.system(size: 17, weight: .bold))
                Text("We're setting up the connection to synchronize your bookmarks and saved logins with the other device.")
                    .frame(width: 320, alignment: .center)
                    .multilineTextAlignment(.center)
                    .fixedSize()
            }
            .frame(width: 320)
        } buttons: {
        }
        .padding(.vertical, 20)
    }

}
