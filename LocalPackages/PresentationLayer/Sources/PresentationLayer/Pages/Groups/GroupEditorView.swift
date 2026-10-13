//
// GroupEditorView.swift
// Altosec Authenticator - Created on 12/10/2026.
// Copyright (c) 2026 Proton Technologies AG
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

import Models
import SwiftUI

/// Form used to create or edit a single group (name, symbol and color).
struct GroupEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var group: EntryGroup
    @State private var isSaving = false
    @FocusState private var nameFocused: Bool

    private let isNew: Bool
    private let onSave: (EntryGroup) async -> Bool

    init(group: EntryGroup, onSave: @escaping (EntryGroup) async -> Bool) {
        _group = State(initialValue: group)
        isNew = group.name.isEmpty
        self.onSave = onSave
    }

    private var canSave: Bool {
        !group.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    preview
                    nameField
                    colorSection
                    symbolSection
                }
                .padding(DesignConstant.padding)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(Text(isNew ? "New group" : "Edit group", bundle: .module))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel", bundle: .module)
                        }
                        .adaptiveButtonStyle()
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            save()
                        } label: {
                            Text("Save", bundle: .module)
                                .fontWeight(.semibold)
                        }
                        .adaptiveButtonStyle()
                        .disabled(!canSave)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .fullScreenMainBackground()
                .task {
                    try? await Task.sleep(for: .milliseconds(150))
                    nameFocused = isNew
                }
        }
        #if os(macOS)
        .fontScaled()
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 360, minHeight: 460, idealHeight: 540)
        #endif
    }

    private var preview: some View {
        HStack(spacing: 12) {
            EntryIconView(icon: .symbol(name: group.symbolName, colorHex: group.colorHex), size: 56, cornerRadius: 14)
                .equatable()
            Text(verbatim: group.name.isEmpty ? "—" : group.name)
                .dynamicFont(size: 20, textStyle: .title3, weight: .semibold)
                .foregroundStyle(.textNorm)
                .lineLimit(1)
            Spacer()
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Name", bundle: .module)
                .foregroundStyle(.textNorm)
                .dynamicFont(size: 12, textStyle: .caption1)
            TextField(text: $group.name, prompt: Text("Work, Personal, Family…", bundle: .module)) {
                EmptyView()
            }
            .adaptiveTextFieldStyle()
            .focused($nameFocused)
            .dynamicFont(size: 18, textStyle: .body)
            .foregroundStyle(.textNorm)
            .onSubmit(save)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.inputBackground)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .inset(by: 0.5)
            .stroke(.inputBorder, lineWidth: 1))
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color", bundle: .module)
                .foregroundStyle(.textWeak)
                .dynamicFont(size: 13, textStyle: .footnote)
            ColorPaletteRow(selectedHex: $group.colorHex)
        }
    }

    private var symbolSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Symbol", bundle: .module)
                .foregroundStyle(.textWeak)
                .dynamicFont(size: 13, textStyle: .footnote)
            SymbolGrid(selected: $group.symbolName, colorHex: group.colorHex)
        }
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        Task {
            let saved = await onSave(group)
            isSaving = false
            if saved {
                dismiss()
            }
        }
    }
}

/// Horizontal selector for the curated color palette.
struct ColorPaletteRow: View {
    @Binding var selectedHex: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(IconPalette.hexValues, id: \.self) { hex in
                    let color = Color(hex: hex) ?? .accentColor
                    let selected = (selectedHex ?? IconPalette.default).uppercased() == hex.uppercased()
                    Button {
                        selectedHex = hex
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 30, height: 30)
                            .overlay {
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .overlay(Circle().stroke(.white.opacity(selected ? 0.9 : 0), lineWidth: 2))
                            .padding(2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: hex))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }
}

/// Grid of SF Symbols tinted with the chosen color.
struct SymbolGrid: View {
    @Binding var selected: String
    let colorHex: String?

    private let columns = [GridItem](repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(IconSymbols.all, id: \.self) { name in
                let isSelected = name == selected
                Button {
                    selected = name
                } label: {
                    EntryIconView(icon: .symbol(name: name, colorHex: colorHex), size: 44, cornerRadius: 10)
                        .equatable()
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Color.purpleInteraction : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: name))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
