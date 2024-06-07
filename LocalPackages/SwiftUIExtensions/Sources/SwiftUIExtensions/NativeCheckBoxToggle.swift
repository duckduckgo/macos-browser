//
//  NativeCheckBoxToggle.swift
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
import AppKit

public struct NativeCheckboxToggle: NSViewRepresentable {
    public typealias NSViewType = NSButton

    @Binding var isOn: Bool
    var label: String

    public init(isOn: Binding<Bool>, label: String) {
       self._isOn = isOn
       self.label = label
   }

    public func makeNSView(context: Context) -> NSButton {
        let button = NSButton(checkboxWithTitle: label, target: context.coordinator, action: #selector(context.coordinator.toggleChecked))
        return button
    }

    public func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.state = isOn ? .on : .off
        nsView.title = label
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject {
        var parent: NativeCheckboxToggle

        init(_ parent: NativeCheckboxToggle) {
            self.parent = parent
        }

        @objc func toggleChecked(sender: NSButton) {
            parent.isOn = sender.state == .on
        }
    }
}

struct NativeCheckboxToggle_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            NativeCheckboxToggle(isOn: .constant(true), label: "Native Checkbox On")
            NativeCheckboxToggle(isOn: .constant(false), label: "Native Checkbox Off")
        }
        .padding()
    }
}
