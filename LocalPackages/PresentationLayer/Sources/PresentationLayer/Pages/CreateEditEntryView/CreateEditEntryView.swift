//
// CreateEditEntryView.swift
// Altosec Authenticator - Created on 10/02/2025.
// Copyright (c) 2025 Proton Technologies AG
//
// This file is part of Altosec Authenticator.
//
// Altosec Authenticator is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Altosec Authenticator is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Altosec Authenticator. If not, see https://www.gnu.org/licenses/.
//

import CommonUtilities
import FactoryKit
import Models
import SwiftUI

private struct TextFieldConfig {
    let title: LocalizedStringKey
    let placeholder: LocalizedStringKey
    var isSecret = false
    let binding: Binding<String>
    let field: FocusableField

    #if os(iOS)
    var capitalization: TextInputAutocapitalization = .sentences
    #endif

    func finalBinding(_ focusedField: FocusableField?) -> Binding<String> {
        focusedField == field || !isSecret ?
            binding : .constant(String(repeating: "•", count: binding.wrappedValue.count))
    }
}

private enum FocusableField: Int, Hashable, CaseIterable {
    case name, secret, issuer
}

struct CreateEditEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateEditEntryViewModel
    @State private var showAdvanceOptions = false
    @State private var showIconPicker = false
    @FocusState private var focusedField: FocusableField?

    private let requestForReview = resolve(\UseCaseContainer.requestForReview)

    init(entry: EntryUiModel?, initialGroupId: String? = nil) {
        _viewModel = .init(wrappedValue: CreateEditEntryViewModel(entry: entry, initialGroupId: initialGroupId))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    textField(TextFieldConfig(title: "Title (Required)",
                                              placeholder: "Title",
                                              binding: $viewModel.name,
                                              field: .name))

                    #if os(iOS)
                    if #available(iOS 18, *) {
                        textField(secretFieldConfig)
                    } else {
                        textField(TextFieldConfig(title: "Secret (Required)",
                                                  placeholder: "Secret",
                                                  binding: $viewModel.secret,
                                                  field: .secret,
                                                  capitalization: .characters))
                    }
                    #else
                    textField(secretFieldConfig)
                    #endif

                    if viewModel.type == .totp {
                        textField(TextFieldConfig(title: "Issuer",
                                                  placeholder: "Issuer",
                                                  binding: $viewModel.issuer,
                                                  field: .issuer))
                    }

                    iconRow

                    if !viewModel.groups.isEmpty {
                        groupRow
                    }

                    if showAdvanceOptions {
                        if viewModel.type == .totp {
                            pickerSection
                        }
                        segmentedControlSection
                    } else {
                        advancedOptionsButton
                    }
                }
                .onSubmit(focusNextField)
            }
            .padding(.bottom, 10)
            .scrollContentBackground(.hidden)
            .errorMessageAlert($viewModel.errorMessage)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar { toolbarContent }
                .navigationTitle(Text(viewModel.isEditing ? "Update Entry" : "New Entry",
                                      bundle: .module))
                .animation(.default, value: viewModel.canSave)
                .animation(.default, value: viewModel.type)
                .animation(.default, value: showAdvanceOptions)
                .fullScreenMainBackground()
                .task {
                    try? await Task.sleep(for: .milliseconds(200))
                    focusFirstField()
                }
                .sheetAlertService()
                .onChange(of: viewModel.shouldDismiss) {
                    if viewModel.shouldDismiss {
                        dismiss()
                        Task {
                            await requestForReview()
                        }
                    }
                }
                .onChange(of: focusedField) { _, _ in
                    viewModel.trimInputs()
                }
                .showSpinner(viewModel.saving)
                .sheet(isPresented: $showIconPicker) {
                    IconPickerView(current: viewModel.icon,
                                   issuerInfo: viewModel.previewIssuerInfo,
                                   letter: viewModel.previewLetter) { icon in
                        viewModel.icon = icon
                    }
                    .resizableSheet()
                }
        }
        #if os(macOS)
        .fontScaled()
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 360, minHeight: 460, idealHeight: 540)
        #endif
    }

    /// Row showing the icon used for the entry, tap to override it.
    private var iconRow: some View {
        Button {
            focusedField = nil
            showIconPicker = true
        } label: {
            HStack(spacing: 12) {
                EntryIconView(icon: ResolvedEntryIcon.resolve(override: viewModel.icon,
                                                              issuerInfo: viewModel.previewIssuerInfo,
                                                              letter: viewModel.previewLetter,
                                                              catalog: ToolsContainer.shared.brandIconCatalog()),
                              size: 36,
                              cornerRadius: 9)
                    .equatable()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Icon", bundle: .module)
                        .foregroundStyle(.textNorm)
                        .dynamicFont(size: 12, textStyle: .caption1)
                    Text(viewModel.icon == nil ? "Automatic" : "Custom", bundle: .module)
                        .foregroundStyle(.textWeak)
                        .dynamicFont(size: 16, textStyle: .callout)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.textWeak)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.inputBackground)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .inset(by: 0.5)
                .stroke(.inputBorder, lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityLabel(Text("Icon", bundle: .module))
    }

    /// Row selecting the group the entry belongs to.
    private var groupRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Group", bundle: .module)
                    .foregroundStyle(.textNorm)
                    .dynamicFont(size: 12, textStyle: .caption1)
                if let group = viewModel.selectedGroup {
                    Label {
                        Text(verbatim: group.name)
                    } icon: {
                        Image(systemName: group.symbolName)
                            .foregroundStyle(group.colorHex.flatMap { Color(hex: $0) } ?? .purpleInteraction)
                    }
                    .foregroundStyle(.textNorm)
                    .dynamicFont(size: 16, textStyle: .callout)
                } else {
                    Text("No group", bundle: .module)
                        .foregroundStyle(.textWeak)
                        .dynamicFont(size: 16, textStyle: .callout)
                }
            }
            Spacer()
            Menu {
                Button {
                    viewModel.groupId = nil
                } label: {
                    if viewModel.groupId == nil {
                        Label("No group", systemImage: "checkmark")
                    } else {
                        Text("No group", bundle: .module)
                    }
                }
                Divider()
                ForEach(viewModel.groups) { group in
                    Button {
                        viewModel.groupId = group.id
                    } label: {
                        if viewModel.groupId == group.id {
                            Label(group.name, systemImage: "checkmark")
                        } else {
                            Label(group.name, systemImage: group.symbolName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Change", bundle: .module)
                    Image(systemName: "chevron.up.chevron.down")
                }
                .foregroundStyle(.purpleInteraction)
                .dynamicFont(size: 15, textStyle: .subheadline, weight: .medium)
            }
            #if os(macOS)
            .menuStyle(.borderlessButton)
            #endif
            .fixedSize()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.inputBackground)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .inset(by: 0.5)
            .stroke(.inputBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func textField(_ config: TextFieldConfig) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(config.title, bundle: .module)
                .foregroundStyle(.textNorm)
                .dynamicFont(size: 12, textStyle: .caption1)

            TextField(config.placeholder, text: config.finalBinding(focusedField))
                .adaptiveTextFieldStyle()
                .onSubmit(focusNextField)
                .focused($focusedField, equals: config.field)
                .dynamicFont(size: 18, textStyle: .body)
                .foregroundStyle(.textNorm)
                .autocorrectionDisabled(true)
                .frame(minHeight: 25)
            #if os(iOS)
                .textInputAutocapitalization(config.capitalization)
            #endif
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.inputBackground)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .inset(by: 0.5)
            .stroke(.inputBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var secretFieldConfig: TextFieldConfig {
        #if os(iOS)
        TextFieldConfig(title: "Secret (Required)",
                        placeholder: "Secret",
                        isSecret: true,
                        binding: $viewModel.secret,
                        field: .secret,
                        capitalization: .characters)
        #else
        TextFieldConfig(title: "Secret (Required)",
                        placeholder: "Secret",
                        isSecret: true,
                        binding: $viewModel.secret,
                        field: .secret)
        #endif
    }
}

// MARK: - Advance options

private extension CreateEditEntryView {
    @ViewBuilder
    var advancedOptionsButton: some View {
        if #available(iOS 26, macOS 26, *) {
            Button(action: {
                       showAdvanceOptions.toggle()
                       focusedField = nil
                   },
                   label: {
                       HStack(alignment: .center, spacing: 8) {
                           Text("Advanced options", bundle: .module)
                               .dynamicFont(size: 18, textStyle: .body)
                           Spacer()
                           Image(systemName: "plus")
                               .resizable()
                               .scaledToFit()
                               .frame(width: 18, height: 18)
                       }
                       .foregroundStyle(.textNorm)
                       .padding()
                   })
                   .buttonStyle(.glass)
                   .glassEffect()
                   .padding(.horizontal)
        } else {
            Button {
                showAdvanceOptions.toggle()
                focusedField = nil
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    Text("Advanced options", bundle: .module)
                        .dynamicFont(size: 18, textStyle: .body)
                        .foregroundStyle(.textNorm)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    Spacer()
                    Image(systemName: "plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.textNorm)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(.dropdownBackground)
                .clipShape(.rect(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
            .adaptiveButtonStyle()
            .impactHaptic()
            .optionShadow()
        }
    }

    var pickerSection: some View {
        VStack {
            pickerFields(title: "Digits",
                         description: { .verbatim("\($0)") },
                         data: viewModel.supportedDigits,
                         binding: $viewModel.digits)
            pickerFields(title: "Time interval",
                         description: { .localized("\($0) seconds", .module) },
                         data: viewModel.supportedPeriod,
                         binding: $viewModel.period)
        }
        .padding(16)
    }

    @ViewBuilder
    func pickerFields(title: LocalizedStringKey,
                      description: @escaping (Int) -> TextContent,
                      data: [Int],
                      binding: Binding<Int>) -> some View {
        if #available(iOS 26, macOS 26, *) {
            LabeledContent(content: {
                Picker(selection: binding,
                       content: {
                           ForEach(data, id: \.self) { element in
                               Text(description(element)) // ignore:missing_bundle
                                   .tag(element)
                           }
                       },
                       label: {
                           EmptyView()
                       })
                       .accentColor(.textNorm)
                       .pickerStyle(.menu)
                       .labelsHidden()
            }, label: {
                Text(title, bundle: .module)
                    .dynamicFont(size: 18, textStyle: .body)
                    .foregroundStyle(.textNorm)
            })
            .padding()
            .background(Color.dropdownBackground)
            .clipShape(.capsule)
        } else {
            HStack(alignment: .center, spacing: 8) {
                Text(title, bundle: .module)
                    .dynamicFont(size: 18, textStyle: .body)
                    .foregroundStyle(.textNorm)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                Spacer()
                Picker(selection: binding,
                       content: {
                           ForEach(data, id: \.self) { element in
                               Text(description(element)) // ignore:missing_bundle
                                   .tag(element)
                           }
                       },
                       label: { Text(verbatim: "") })
                    .accentColor(.textNorm)
                    .pickerStyle(pickerStyle)
                    .labelsHidden()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(.dropdownBackground)
            .clipShape(.rect(cornerRadius: 16))
            .optionShadow()
        }
    }

    @ViewBuilder
    var segmentedControlSection: some View {
        if viewModel.type == .totp {
            segmentedControlField(title: "ALGORITHM", data: TotpAlgorithm.allCases, binding: $viewModel.algo)
                .impactHaptic()
        }

        segmentedControlField(title: "TYPE", data: TotpType.allCases, binding: $viewModel.type)
            .impactHaptic()
    }

    func segmentedControlField<T: CustomSegmentedControlData>(title: LocalizedStringKey,
                                                              data: [T],
                                                              binding: Binding<T>) -> some View {
        Section {
            if #available(iOS 26, macOS 26, *) {
                Picker(selection: binding,
                       content: {
                           ForEach(data, id: \.self) { type in
                               Text(verbatim: "\(type.rawValue)".uppercased())
                                   .font(AppConstants.isMacOS ? .body : .title)
                                   .fontWeight(.semibold)
                                   .foregroundStyle(.textNorm)
                           }
                       }, label: {
                           EmptyView()
                       })
                       .pickerStyle(.segmented)
                       .labelsHidden()
                       .controlSize(.extraLarge)
            } else {
                CustomSegmentedControl(data: data, selection: binding)
            }
        } header: {
            HStack {
                Text(title, bundle: .module)
                    .dynamicFont(size: 13, textStyle: .footnote)
                    .foregroundStyle(.textNorm)
                    .opacity(0.7)
                    .padding(.leading, 16)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Focus and button placements

private extension CreateEditEntryView {
    var toolbarItemTrailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .confirmationAction
        #endif
    }

    var toolbarItemLeadingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .confirmationAction
        #endif
    }

    var pickerStyle: some PickerStyle {
        #if os(iOS)
        return .automatic
        #else
        return .segmented
        #endif
    }

    func focusFirstField() {
        focusedField = FocusableField.allCases.first
    }

    func focusNextField() {
        switch focusedField {
        case .name:
            focusedField = .secret

        case .secret:
            if viewModel.type == .totp {
                focusedField = .issuer
            } else {
                focusedField = nil
            }

        case .issuer:
            focusedField = nil

        case .none:
            break
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(macOS)
        ToolbarItemGroup(placement: toolbarItemTrailingPlacement) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Close", bundle: .module)
                        .foregroundStyle(.accent)
                        .padding(10)
                }
                .adaptiveButtonStyle()
                .keyboardShortcut(.escape)

                Button {
                    viewModel.save()
                } label: {
                    Text("Save", bundle: .module)
                        .fontWeight(.semibold)
                        .foregroundStyle(.accent)
                        .padding(10)
                }
                .adaptiveButtonStyle()
                .disabled(!viewModel.canSave)
                .opacity(viewModel.canSave ? 1 : 0.4)
                .keyboardShortcut("s")
            }
        }
        #else
        ToolbarItem(placement: toolbarItemLeadingPlacement) {
            Button(action: dismiss.callAsFunction) {
                if #available(iOS 26, macOS 26, *) {
                    Image(systemName: "xmark")
                } else {
                    Text("Close", bundle: .module)
                        .foregroundStyle(.accent)
                        .padding(10)
                        .adaptiveButtonStyle()
                }
            }
        }

        ToolbarItem(placement: toolbarItemTrailingPlacement) {
            Group {
                if #available(iOS 26, macOS 26, *) {
                    Button {
                        viewModel.save()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .adaptiveGlassProminentStyle()
                    .tint(.accent)
                    .disabled(!viewModel.canSave)
                    .opacity(viewModel.canSave ? 1 : 0.4)
                } else {
                    Button {
                        viewModel.save()
                    } label: {
                        Text("Save", bundle: .module)
                            .fontWeight(.semibold)
                            .foregroundStyle(.accent)
                            .padding(10)
                    }
                    .adaptiveButtonStyle()
                }
            }
            .disabled(!viewModel.canSave)
            .opacity(viewModel.canSave ? 1 : 0.4)
        }
        #endif
    }
}

#Preview {
    CreateEditEntryView(entry: nil)
}

private extension View {
    @available(iOS 26, macOS 26, *)
    @ViewBuilder
    func adaptiveGlassProminentStyle() -> some View {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(.glassProminent)
        }
    }
}
