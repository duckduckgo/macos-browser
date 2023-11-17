//
//  DataImportSourcePicker.swift
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

@MainActor
struct DataImportSourcePicker: View {

    @State private var viewModel: DataImportSourceViewModel

    private var importSources: [DataImport.Source] {
        viewModel.importSources
    }

    init(selectedSource: DataImport.Source,
         onSelectedSourceChanged: @escaping (DataImport.Source) -> Void) {
        self.viewModel = DataImportSourceViewModel(selectedSource: selectedSource, onSelectedSourceChanged: onSelectedSourceChanged)
    }

    var body: some View {
        Picker(selection: $viewModel.selectedSourceIndex) {
            ForEach(importSources.indices, id: \.self) { idx in
                HStack {
                    // The CSV row is at the bottom of the picker, and requires a separator above it, but only if the item array isn't
                    // empty (which would happen if there are no valid sources).
                    if idx > 0, [.onePassword8, .csv].contains(importSources[idx]) {
                        Divider()
                    }

                    if let icon = importSources[idx].importSourceImage?.resized(to: NSSize(width: 16, height: 16)) {
                        Image(nsImage: icon)
                    }
                    Text(importSources[idx].importSourceName)
                }
            }
        } label: {}
            .onChange(of: viewModel.selectedSourceIndex) { idx in
                viewModel.onSelectedSourceChanged(importSources[idx])
            }
            .pickerStyle(MenuPickerStyle())
    }

}

#Preview {
    DataImportSourcePicker(selectedSource: .csv) {
        print("seiection:", $0)
    }
}
