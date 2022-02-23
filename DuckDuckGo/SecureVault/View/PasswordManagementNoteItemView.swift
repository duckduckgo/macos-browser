//
//  PasswordManagementNoteItemView.swift
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

import SwiftUI
import BrowserServicesKit

private let interItemSpacing: CGFloat = 23
private let itemSpacing: CGFloat = 13

struct PasswordManagementNoteItemView: View {

    @EnvironmentObject var model: PasswordManagementNoteModel

    var body: some View {
        
        if model.note != nil {
            
            let editMode = model.isEditing || model.isNew
            
            ZStack(alignment: .top) {
                Spacer()
                
                if editMode {
                    
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(Color(NSColor.editingPanelColor))
                        .shadow(radius: 6)
                    
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    
                    HeaderView()
                        .padding(.bottom, editMode ? 20 : 30)
                    
                    TextView()
                    
                    Spacer(minLength: 0)
                    
                    Buttons()
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                
            }
            .padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 10))
            
        }
        
    }

}

// MARK: - Generic Views

private struct Buttons: View {

    @EnvironmentObject var model: PasswordManagementNoteModel

    var body: some View {
        HStack {

            if model.isEditing && !model.isNew {
                Button(UserText.pmDelete) {
                    model.requestDelete()
                }
                .buttonStyle(StandardButtonStyle())
            }

            Spacer()

            if model.isEditing || model.isNew {
                Button(UserText.pmCancel) {
                    model.cancel()
                }
                .buttonStyle(StandardButtonStyle())
                Button(UserText.pmSave) {
                    model.save()
                }
                .disabled(!model.isDirty)
                .buttonStyle(DefaultActionButtonStyle(enabled: model.isDirty))

            } else {
                Button(UserText.pmDelete) {
                    model.requestDelete()
                }
                .buttonStyle(StandardButtonStyle())

                Button(UserText.pmEdit) {
                    model.edit()
                }
                .buttonStyle(StandardButtonStyle())

            }

        }
    }

}

// MARK: - Note Views

private struct NoteTitleView: View {

    @EnvironmentObject var model: PasswordManagementNoteModel

    var body: some View {

        Text(UserText.pmNotes)
            .bold()
            .padding(.bottom, itemSpacing)

        TextField("", text: $model.title)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.bottom, interItemSpacing)

    }

}

private struct TextView: View {

    @EnvironmentObject var model: PasswordManagementNoteModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            if model.isEditing || model.isNew {

                EditableTextView(text: $model.text)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4.0)
                        .stroke(Color.init(NSColor.tertiaryLabelColor), lineWidth: 1)
                    )
                    .padding(.bottom, interItemSpacing)

            } else {

                HStack {
                    if #available(macOS 12, *) {
                        Text(model.text)
                            .foregroundColor(Color.primary)
                            .textSelection(.enabled)
                    } else {
                        Text(model.text)
                    }

                    Spacer()
                }
                .padding(.bottom, interItemSpacing)
            }

        }
    }

}

private struct HeaderView: View {

    @EnvironmentObject var model: PasswordManagementNoteModel

    var body: some View {

        HStack(alignment: .center, spacing: 0) {

            Image("Note")
                .padding(.trailing, 10)

            if model.isNew || model.isEditing {

                TextField("", text: $model.title)
                    .font(.title)

            } else {

                Text(model.title)
                    .font(.title)

            }

        }

    }

}
