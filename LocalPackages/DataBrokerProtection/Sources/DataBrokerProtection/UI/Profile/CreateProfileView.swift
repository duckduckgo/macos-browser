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
    @ObservedObject var viewModel: ProfileViewModel
    let scanButtonClicked: () -> Void
    let backToDashboardClicked: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack (alignment: .top) {
            VStack {
                FormHeaderView()
                    .padding(.horizontal, Consts.OuterForm.horizontalPadding)

                if viewModel.hasOperationContent {
                    Button {
                        backToDashboardClicked()
                    } label: {
                        Text("􀰌 Back to Dashboard")
                            .padding(.horizontal, Consts.Button.horizontalPadding)
                            .padding(.vertical, Consts.Button.verticalPadding)
                    }
                    .buttonStyle(CTAButtonStyle(style: .outlined))
                    .padding(.top, 12)
                }

                ComponentsContainerView(viewModel: viewModel)
                    .padding()

                FormFooterView(viewModel: viewModel, buttonClicked: {
                    viewModel.saveProfile {
                        scanButtonClicked()
                    }
                })
                .padding()
                .padding(.horizontal, Consts.OuterForm.horizontalPadding)
            }
            .shadedBorderedPanel(backgroundColor: Color("profile-background-color", bundle: .module))

            Image("header-hero", bundle: .module)
                .offset(y: -15)
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
                   setEditViewVisible(false)
                }
            } else {
                if let birthYear = viewModel.birthYear {
                    EditFieldView(enabled: true, label: "\(birthYear)") {
                        withAnimation {
                            isEditViewVisible = true
                        }
                    }
                    .padding(.horizontal, Consts.EditField.horizontalPadding)
                    .padding(.vertical, Consts.EditField.verticalPadding)
                    .borderedRoundedCorner(backgroundColor: Color("modal-background-color", bundle: .module))

                } else {
                    Button {
                        setEditViewVisible(true)
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

    private func setEditViewVisible(_ visible: Bool) {
        withAnimation {
            isEditViewVisible = visible
        }
    }
}

private struct BirthYearFormView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var selectedYear = ProfileViewModel.minimumBirthYear

    let completion: () -> Void

    var body: some View {
        VStack(spacing: 15) {

            VStack(alignment: .leading) {
                Text("Birth Year*")
                    .foregroundColor(.secondary)

                Picker(selection: $selectedYear) {
                    ForEach(viewModel.birthdayYearRange, id: \.self) { year in
                        Text(String(year))
                            .tag(year)
                    }
                } label: { }
            }
            .padding(.bottom, 20)

            CTAFooterView(showDeleteButton: false,
                          saveButtonEnabled: true) {
                withAnimation {
                    viewModel.birthYear = selectedYear
                }
                completion()
            } cancelButtonClicked: {
                completion()
            } deleteButtonClicked: { }
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
    @State private var isEditViewVisible = false

    var body: some View {
        VStack(alignment: .leading) {
            ComponentHeaderView(title: "Name",
                                subtitle: "Providing your full name, nicknames, and maiden name, if applicable, can help us find additional matches.",
                                isValidated: viewModel.isNameValid)

            EditViewList(viewModel.names) { name in
                EditFieldView(enabled: !isEditViewVisible, label: name.fullName) {
                    viewModel.selectedName = name
                    setEditViewVisible(true)
                }
            }

            if isEditViewVisible {
                NameFormView(viewModel: viewModel) {
                    setEditViewVisible(false)
                }
            } else {
                Button {
                    viewModel.selectedName = nil
                    setEditViewVisible(true)
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

    private func setEditViewVisible(_ visible: Bool) {
        withAnimation {
            isEditViewVisible = visible
        }
    }
}

private struct NameFormView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let completion: () -> Void

    @State private var firstName = ""
    @State private var middleName = ""
    @State private var lastName = ""
    @State private var suffix = ProfileViewModel.defaultSuffixSelection
    @State private var shouldShowDeleteButton = false

    var body: some View {
        VStack(spacing: 15) {
            TextFieldWithLabel(label: "First Name*", text: $firstName)
            TextFieldWithLabel(label: "Middle Name", text: $middleName)
            TextFieldWithLabel(label: "Last Name*", text: $lastName)

            VStack(alignment: .leading) {
                Text("Suffix")
                    .foregroundColor(.secondary)

                Picker(selection: $suffix) {
                    ForEach(viewModel.suffixes, id: \.self) { suffix in
                        Text(suffix)
                            .tag(suffix)
                    }
                } label: { }
            }
            .padding(.bottom, 20)

            CTAFooterView(showDeleteButton: shouldShowDeleteButton,
                           saveButtonEnabled: areRequiredFormsFilled()) {
                save()
                completion()
            } cancelButtonClicked: {
                completion()
            } deleteButtonClicked: {
                delete()
                completion()
            }
        }
        .padding(Consts.Form.padding)
        .borderedRoundedCorner()
        .onAppear {
            if let selectedName = viewModel.selectedName {
                shouldShowDeleteButton = true
                firstName = selectedName.firstName
                middleName = selectedName.middleName
                lastName = selectedName.lastName
                suffix = selectedName.suffix.isEmpty ? ProfileViewModel.defaultSuffixSelection : selectedName.suffix
            }
        }
    }

    private func save() {
        withAnimation {
            viewModel.saveName(
                id: viewModel.selectedName?.id,
                firstName: firstName,
                middleName: middleName,
                lastName: lastName,
                suffix: suffix)
        }
    }

    private func delete() {
        if let id = viewModel.selectedName?.id {
            withAnimation {
                viewModel.deleteName(id)
            }
        }
    }

    private func areRequiredFormsFilled() -> Bool {
        return [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)}
            .allSatisfy { !$0.isEmpty }
    }
}

// MARK: - Address

@available(macOS 11.0, *)
private struct AddressComponentView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var isEditViewVisible = false

    var body: some View {

        VStack(alignment: .leading) {
            ComponentHeaderView(title: "Address",
                                subtitle: "Providing your full address can help us find a match faster. You can add up to 3 previous addresses.",
                                isValidated: viewModel.isAddressValid)

            EditViewList(viewModel.addresses) { address in
                EditFieldView(enabled: !isEditViewVisible,
                              label: address.fullAddress) {
                    viewModel.selectedAddress = address
                    setEditViewVisible(true)
                }
            }

            if isEditViewVisible {
                AddressFormView(viewModel: viewModel) {
                    setEditViewVisible(false)
                }
            } else {
                Button {
                    viewModel.selectedAddress = nil
                    setEditViewVisible(true)
                } label: {
                    Text("Add address")
                        .padding(.horizontal, Consts.Button.horizontalPadding)
                        .padding(.vertical, Consts.Button.verticalPadding)
                }
                .buttonStyle(CTAButtonStyle())
                .padding(.top, 12)
            }
        }
        .frame(width: Consts.Form.width)
    }

    private func setEditViewVisible(_ visible: Bool) {
        withAnimation {
            isEditViewVisible = visible
        }
    }
}

private struct AddressFormView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let completion: () -> Void

    @State private var street = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var shouldShowDeleteButton = false

    var body: some View {
        VStack(spacing: 15) {
            TextFieldWithLabel(label: "Street", text: $street)
            TextFieldWithLabel(label: "City*", text: $city)

            VStack(alignment: .leading) {
                Text("State*")
                    .foregroundColor(.secondary)

                Picker(selection: $state) {
                    ForEach(viewModel.states, id: \.self) { state in
                        if state != ProfileViewModel.defaultStateSelection {
                            Text(state)
                                .tag(state)
                        }
                    }
                } label: { }
            }

            TextFieldWithLabel(label: "Zip Code", text: $zip)
            .padding(.bottom, 20)

            CTAFooterView(
                showDeleteButton: shouldShowDeleteButton,
                saveButtonEnabled: areRequiredFormsFilled()) {
                    save()
                    completion()
                } cancelButtonClicked: {
                    completion()
                } deleteButtonClicked: {
                    delete()
                    completion()
                }
        }
        .padding(Consts.Form.padding)
        .borderedRoundedCorner()
        .onAppear {
            if let selectedAddress = viewModel.selectedAddress {
                shouldShowDeleteButton = true
                street = selectedAddress.street
                city = selectedAddress.city
                state = selectedAddress.state
                zip = selectedAddress.zip
            }
        }
    }

    private func save() {
        withAnimation {
            viewModel.saveAddress(id: viewModel.selectedAddress?.id,
                                  street: street,
                                  city: city,
                                  state: state,
                                  zip: zip)
        }
    }

    private func delete() {
        if let id = viewModel.selectedAddress?.id {
            withAnimation {
                viewModel.deleteAddress(id)
            }
        }
    }

    private func areRequiredFormsFilled() -> Bool {
        if state == ProfileViewModel.defaultStateSelection {
            return false
        }
        return [city, state]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)}
            .allSatisfy { !$0.isEmpty }
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
    @ObservedObject var viewModel: ProfileViewModel

    let buttonClicked: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Button {
                buttonClicked()
            } label: {
                if #available(macOS 11.0, *), viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                } else {
                    Text("Scan")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }

            }
            .buttonStyle(CTAButtonStyle(style: .primary))
            .disabled(!viewModel.isProfileValid)

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
struct EditViewList<Data, Content: View>: View where Data: RandomAccessCollection, Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content

    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    var body: some View {
        if !data.isEmpty {
            VStack {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                    self.content(item)
                        .padding(.horizontal, Consts.EditField.horizontalPadding)
                    if index != self.data.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.vertical, Consts.EditField.verticalPadding)
            .borderedRoundedCorner(backgroundColor: Color("modal-background-color", bundle: .module))
            .transition(.opacity)
        }
    }
}

@available(macOS 11.0, *)
private struct ComponentsContainerView: View {
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

                AddressComponentView(viewModel: viewModel)
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
    }
}

private struct CTAFooterView: View {
    let showDeleteButton: Bool
    let saveButtonEnabled: Bool
    let saveButtonClicked: () -> Void
    let cancelButtonClicked: () -> Void
    let deleteButtonClicked: (() -> Void)?

    var body: some View {
        HStack {
            if showDeleteButton {
                button(title: "Delete",
                       style: .destructive) {
                    deleteButtonClicked?()
                }
                Spacer()
            }

            button(title: "Cancel",
                   style: .secondary) {
                cancelButtonClicked()
            }

            if !showDeleteButton {
                Spacer()
            }

            button(title: "Save",
                   enabled: saveButtonEnabled,
                   style: .primary) {
                saveButtonClicked()
            }
        }
    }

    private func button(title: String,
                        enabled: Bool = true,
                        style: CTAButtonStyle.Style,
                        completion: @escaping  () -> Void) -> some View {
        Button {
            completion()
        } label: {
            Text(title)
                .padding(.horizontal, Consts.Button.horizontalPadding)
                .padding(.vertical, Consts.Button.verticalPadding)
        }
        .buttonStyle(CTAButtonStyle(style: style))
        .disabled(!enabled)
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

    enum EditField {
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 10

    }
    enum OuterForm {
        static let horizontalPadding: CGFloat = 40
    }
}

@available(macOS 11.0, *)
struct CreateProfileView_Previews: PreviewProvider {
    static var previews: some View {
        CreateProfileView(viewModel: ProfileViewModel(dataManager: DataBrokerProtectionDataManager()),
                          scanButtonClicked: {},
                          backToDashboardClicked: {})
            .frame(width: 500, height: 1400)
            .padding(30)
    }
}
