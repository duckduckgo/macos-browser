//
//  ScanStartedView.swift
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

struct ScanStartedView: View {
    var body: some View {
        VStack (spacing: 10) {
            HStack {
                Text("We've started scanning your profile info on Data Brokers.")
                    .font(.title)
                    .bold()
            }
            Text("We should have some results for you shortly.")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct ScanStartedView_Previews: PreviewProvider {
    static var previews: some View {
        ScanStartedView()
    }
}
