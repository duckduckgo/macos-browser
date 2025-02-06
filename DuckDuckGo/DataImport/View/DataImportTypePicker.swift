//
//  DataImportTypePicker.swift
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
import BrowserServicesKit

struct DataImportTypePicker: View {

    @Binding var viewModel: DataImportViewModel

    init(viewModel: Binding<DataImportViewModel>) {
        _viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("What do you want to import?",
                 comment: "Data Import section title for checkboxes of data type to import: Passwords or Bookmarks.")

            ForEach(DataImport.DataType.allCases, id: \.self) { dataType in
                // display all types for a browser disabling unavailable options
                if viewModel.importSource.isBrowser
                    // display only supported types for a non-browser
                    || viewModel.importSource.supportedDataTypes.contains(dataType) {

                    Toggle(isOn: Binding {
                        viewModel.selectedDataTypes.contains(dataType)
                    } set: { isOn in
                        viewModel.setDataType(dataType, selected: isOn)
                    }) {
                        Text(dataType.displayName)
                    }
                    .disabled(!viewModel.importSource.supportedDataTypes.contains(dataType))

                    // subtitle
                    if case .passwords = dataType,
                       !viewModel.importSource.supportedDataTypes.contains(.passwords) {
                        Text("\(viewModel.importSource.importSourceName) does not support storing passwords",
                             comment: "Data Import disabled checkbox message about a browser (%@) not supporting storing passwords")
                            .foregroundColor(Color(.disabledControlTextColor))
                    }
                }
            }
        }
    }

}

extension DataImportViewModel {

    mutating func setDataType(_ dataType: DataType, selected: Bool) {
        if selected {
            selectedDataTypes.insert(dataType)
        } else {
            selectedDataTypes.remove(dataType)
        }
    }

}
