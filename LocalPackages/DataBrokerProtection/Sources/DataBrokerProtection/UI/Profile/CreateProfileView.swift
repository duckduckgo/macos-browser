//
//  CreateProfileView.swift
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

@available(macOS 11.0, *)
struct CreateProfileView: View {
    @StateObject var viewModel = ProfileViewModel()

    var body: some View {
        ZStack {
            VStack {
                FormHeaderView()
                    .padding(.horizontal, Consts.OuterForm.horizontalPadding)

                ComponentsContainerView(viewModel: viewModel)
                    .padding()

                FormFooterView()
                    .padding()
                    .padding(.horizontal, Consts.OuterForm.horizontalPadding)
            }
            .shadedBorderedPanel()

            VStack {
                Image("header-hero", bundle: .module)
                Spacer()
            }
        }
    }
}

// MARK: - Birthday

@available(macOS 11.0, *)
private struct BirthYearComponentView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State var isEditViewVisible = false

    var body: some View {
        VStack(alignment: .leading) {
            ComponentHeaderView(title: "Birth Year",
                                subtitle: "The year you were born helps to bring back more accurate matches.",
                                isValidated: viewModel.isBirthdayValid)

            if isEditViewVisible {
                BirthYearFormView(viewModel: viewModel) {
                    withAnimation {
                        isEditViewVisible = false
                    }
                }
            } else {
                if let birthYear = viewModel.birthYear {
                    EditFieldView(enabled: true, label: "\(birthYear)") {
                        withAnimation {
                            isEditViewVisible = true
                        }
                    }
                } else {
                    Button {
                        withAnimation {
                            isEditViewVisible.toggle()
                        }
                    } label: {
                        Text("Add birth year")
                            .padding(.horizontal, Consts.Button.horizontalPadding)
                            .padding(.vertical, Consts.Button.verticalPadding)
                    }
                    .buttonStyle(CTAButtonStyle())
                    .padding(.top, 12)
                }
            }
        }
        .frame(width: Consts.Form.width)
    }
}

private extension Date {
    var year: Int {
        let calendar = Calendar.current
        return calendar.component(.year, from: self)
    }
}

private struct BirthYearFormView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var selectedYear = Date().year
    let completion: () -> Void

    var body: some View {
        VStack(spacing: 15) {

            VStack(alignment: .leading) {
                Text("Birth Year*")
                    .foregroundColor(.secondary)

                Picker(selection: $selectedYear) {
                    ForEach((Date().year - 110)...(Date().year), id: \.self) { year in
                        Text(String(year))
                            .tag(year)
                    }
                } label: { }
            }
            .padding(.bottom, 20)

            CTAFooterView(
                saveButtonClicked: {
                    withAnimation {
                        viewModel.birthYear = selectedYear
                    }
                    completion()
                },
                cancelButtonClicked: completion)

        }
        .padding(Consts.Form.padding)
        .borderedRoundedCorner()
        .onAppear {
            if let birthYear = viewModel.birthYear {
                selectedYear = birthYear
            }
        }
    }
}

// MARK: - Name

@available(macOS 11.0, *)
private struct NameComponentView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var isEditViewVisible = true

    var body: some View {
        VStack(alignment: .leading) {
            ComponentHeaderView(title: "Name",
                                subtitle: "Providing your full name, nicknames, and maiden name, if applicable, can help us find additional matches.",
                                isValidated: viewModel.isNameValid)
            ForEach(viewModel.names) { name in
                EditFieldView(enabled: !isEditViewVisible, label: name.firstName) {
                    print("NAME \(name.firstName)")
                    viewModel.selectedName = name
                    withAnimation {
                        isEditViewVisible = true
                    }
                }
            }
            if isEditViewVisible {
                NameFormView(viewModel: viewModel) {
                    print("save")
                    withAnimation {
                        isEditViewVisible = false
                    }
                } cancelButtonClicked: {
                    print("cancel")
                    withAnimation {
                        isEditViewVisible = false
                    }
                }
            } else {
                Button {
                    withAnimation {
                        isEditViewVisible.toggle()
                    }
                } label: {
                    Text("Add name")
                        .padding(.horizontal, Consts.Button.horizontalPadding)
                        .padding(.vertical, Consts.Button.verticalPadding)
                }
                .buttonStyle(CTAButtonStyle())
                .padding(.top, 12)
            }

        }
        .frame(width: Consts.Form.width)
    }
}

private struct NameFormView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let saveButtonClicked: () -> Void
    let cancelButtonClicked: () -> Void

    @State private var firstName = ""
    @State private var middleName = ""
    @State private var lastName = ""
    @State private var suffix = ""

    var body: some View {
        VStack(spacing: 15) {
            TextFieldWithLabel(label: "First Name*", text: $firstName)
            TextFieldWithLabel(label: "Middle Name", text: $middleName)
            TextFieldWithLabel(label: "Last Name*", text: $lastName)
            TextFieldWithLabel(label: "Suffix", text: $suffix)
            CTAFooterView(saveButtonClicked: saveButtonClicked,
                          cancelButtonClicked: cancelButtonClicked)
        }
        .padding(Consts.Form.padding)
        .borderedRoundedCorner()
        .onAppear {
            if let selectedName = viewModel.selectedName {
                firstName = selectedName.firstName
                middleName = selectedName.middleName ?? ""
                lastName = selectedName.lastName
                suffix = selectedName.suffix ?? ""
            }
        }
    }
}

// MARK: - Address

@available(macOS 11.0, *)
private struct AddressComponentView: View {
    @State private var isSubviewVisible = false

    var body: some View {
        ProfileComponentRow(title: "Address",
                            subtitle: "Providing your full address can help us find a match faster. You can add up to 3 previous addresses.",
                            buttonTitle: "Add address",
                            isValidated: true,
                            isEditViewVisible: $isSubviewVisible) {
           // EditFieldView(label: "Testing")
        } editView: {
            AddressFormView {
                withAnimation {
                    isSubviewVisible.toggle()
                }
            } cancelButtonClicked: {
                withAnimation {
                    isSubviewVisible.toggle()
                }
            }
        }.frame(width: Consts.Form.width)
    }
}

private struct AddressFormView: View {
    let saveButtonClicked: () -> Void
    let cancelButtonClicked: () -> Void
    @State private var street = ""
    @State private var city = ""
    @State private var state = ""
    @State private var selectedState = "Select a State"

    let states = ["AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"]

    var body: some View {
        VStack(spacing: 15) {
            TextFieldWithLabel(label: "Street", text: $street)
            TextFieldWithLabel(label: "City*", text: $city)

            VStack(alignment: .leading) {
                Text("State*")
                    .foregroundColor(.secondary)

                Picker(selection: $selectedState) {
                    ForEach(states, id: \.self) { state in
                        Text(state)
                    }
                } label: { }
            }
            .padding(.bottom, 20)

            CTAFooterView(saveButtonClicked: saveButtonClicked,
                          cancelButtonClicked: cancelButtonClicked)
        }.padding(Consts.Form.padding)
            .borderedRoundedCorner()
    }
}

// MARK: - Header / Footer

private struct FormHeaderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Your Profile")
                .font(.title)
                .bold()

            Text("The following information is required for Data Broker Protection. We’ll scan Data Broker sites for matching info and have it removed.")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

private struct FormFooterView: View {
    var body: some View {
        VStack(spacing: 16) {
            Button {
               print("Scan")
            } label: {
                Text("Scan")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }.buttonStyle(CTAButtonStyle(style: .secundary))

            Text("The information you've entered stays on your device, it does not go through DuckDuckGo's servers.")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Helpers

@available(macOS 11.0, *)
private struct ComponentsContainerView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
            VStack {
                NameComponentView(viewModel: viewModel)
                    .padding()

                Divider()
                    .padding(.horizontal)

                BirthYearComponentView(viewModel: viewModel)
                    .padding()

                Divider()
                    .padding(.horizontal)

                AddressComponentView()
                    .padding()
            }
            .padding()
            .borderedRoundedCorner()
    }
}

struct TextFieldWithLabel: View {
    var label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .foregroundColor(.secondary)

            TextField("", text: $text)
                .padding(8)
                .frame(height: 44)

                .textFieldStyle(.plain)
                .borderedRoundedCorner()
        }
    }
}

private struct EditFieldView: View {
    let enabled: Bool
    let label: String
    let editAction: () -> Void

    var body: some View {
        HStack {
            Text(label)

            Spacer()

            Button {
                editAction()
            } label: {
                Text("Edit")
                    .padding(.horizontal, Consts.Button.horizontalPadding)
                    .padding(.vertical, Consts.Button.verticalPadding)

            }
            .buttonStyle(CTAButtonStyle())
            .disabled(!enabled)

        }
        .padding(16)
        .frame(height: 56)
        .borderedRoundedCorner(backgroundColor: .secondary)
    }
}

private struct CTAFooterView: View {
    let saveButtonClicked: () -> Void
    let cancelButtonClicked: () -> Void

    var body: some View {
        HStack {
            Button {
                cancelButtonClicked()
            } label: {
                Text("Cancel")
                    .padding(.horizontal, Consts.Button.horizontalPadding)
                    .padding(.vertical, Consts.Button.verticalPadding)

            }.buttonStyle(CTAButtonStyle(style: .secundary))

            Spacer()

            Button {
                saveButtonClicked()
            } label: {
                Text("Save")
                    .padding(.horizontal, Consts.Button.horizontalPadding)
                    .padding(.vertical, Consts.Button.verticalPadding)
            }
            .buttonStyle(CTAButtonStyle())
        }
    }
}

@available(macOS 11.0, *)
private struct ProfileComponentRow<SavedItemsView: View, EditItemView: View>: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let isValidated: Bool

    @Binding var isEditViewVisible: Bool
    @ViewBuilder var savedItemsView: SavedItemsView
    @ViewBuilder var editView: EditItemView

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                headerView
                Spacer()
            }

            if !isEditViewVisible {
                savedItemsView

                Button(action: {
                    withAnimation {
                        self.isEditViewVisible.toggle()
                    }
                }) {
                    Text(buttonTitle)
                        .padding(.horizontal, Consts.Button.horizontalPadding)
                        .padding(.vertical, Consts.Button.verticalPadding)

                }.buttonStyle(CTAButtonStyle())
                    .padding(.top, 12)
            }

            if isEditViewVisible {
                editView
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
    }

    @available(macOS 11.0, *)
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.title3)
                    .bold()

                if isValidated {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }

            Text(subtitle)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.secondary)
        }
    }
}

@available(macOS 11.0, *)
private struct ComponentHeaderView: View {
    let title: String
    let subtitle: String
    let isValidated: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.title3)
                        .bold()

                    if isValidated {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                }

                Text(subtitle)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

private enum Consts {
    enum Button {
        static let width: CGFloat = 76
        static let horizontalPadding: CGFloat = 14
        static let verticalPadding: CGFloat = 10
    }

    enum Form {
        static let padding: CGFloat = 24
        static let width: CGFloat = 500
    }

    enum OuterForm {
        static let horizontalPadding: CGFloat = 40
    }
}

@available(macOS 11.0, *)
struct CreateProfileView_Previews: PreviewProvider {
    static var previews: some View {
        CreateProfileView()
            .padding(30)
    }
}
