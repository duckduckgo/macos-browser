//
//  PasswordManagementNoteModel.swift
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
import BrowserServicesKit

final class PasswordManagementNoteModel: ObservableObject, PasswordManagementItemModel {

    typealias Model = SecureVaultModels.Note

    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter
    }()

    var onDirtyChanged: (Bool) -> Void
    var onSaveRequested: (SecureVaultModels.Note) -> Void
    var onDeleteRequested: (SecureVaultModels.Note) -> Void

    var isEditingPublisher: Published<Bool>.Publisher {
        return $isEditing
    }

    var note: SecureVaultModels.Note? {
        didSet {
            populateViewModelFromNote()
        }
    }

    @Published var isEditing = false {
        didSet {
            // Experimental change suggested by the design team to mark an item as dirty as soon as it enters the editing state.
            if isEditing {
                isDirty = true
            }
        }
    }

    @Published var isNew = false

    @Published var title: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var text: String = "" {
        didSet {
            isDirty = true
        }
    }

    var isDirty = false {
        didSet {
            self.onDirtyChanged(isDirty)
        }
    }

    var lastUpdatedDate: String = ""
    var createdDate: String = ""

    init(onDirtyChanged: @escaping (Bool) -> Void,
         onSaveRequested: @escaping (SecureVaultModels.Note) -> Void,
         onDeleteRequested: @escaping (SecureVaultModels.Note) -> Void) {
        self.onDirtyChanged = onDirtyChanged
        self.onSaveRequested = onSaveRequested
        self.onDeleteRequested = onDeleteRequested
    }

    func createNew() {
        note = .init(title: "", text: "")
        isEditing = true
    }

    func cancel() {
        populateViewModelFromNote()
        isEditing = false

        if isNew {
            note = nil
            isNew = false
        }
    }

    func save() {
        guard var note = note else { return }

        note.title = title
        note.text = text

        onSaveRequested(note)
    }

    func clearSecureVaultModel() {
        note = nil
    }

    func setSecureVaultModel<Model>(_ modelObject: Model) {
        guard let modelObject = modelObject as? SecureVaultModels.Note else {
            return
        }

        note = modelObject
    }

    func requestDelete() {
        guard let note = note else { return }
        onDeleteRequested(note)
    }

    func edit() {
        isEditing = true
    }

    private func populateViewModelFromNote() {
        title = note?.title ?? ""
        text = note?.text ?? ""

        isDirty = false

        isNew = note?.id == nil

        if let date = note?.created {
            createdDate = Self.dateFormatter.string(from: date)
        } else {
            createdDate = ""
        }

        if let date = note?.lastUpdated {
            lastUpdatedDate = Self.dateFormatter.string(from: date)
        } else {
            lastUpdatedDate = ""
        }
    }

}
