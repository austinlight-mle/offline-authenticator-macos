//
// IconPickerView.swift
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

import DataLayer
import FactoryKit
import Models
import SwiftUI
import UniformTypeIdentifiers

/// Lets the user pick a bundled brand icon, an SF Symbol or a picture for an entry,
/// or go back to the automatic issuer based icon.
struct IconPickerView: View {
    enum Tab: Int, CaseIterable, Identifiable {
        case brands, symbols, picture

        var id: Int { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .brands: "Brands"
            case .symbols: "Symbols"
            case .picture: "Picture"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .brands
    @State private var query = ""
    @State private var symbolColorHex: String? = IconPalette.default
    @State private var showFileImporter = false
    @State private var errorMessage: String?

    private let catalog = ToolsContainer.shared.brandIconCatalog()

    let current: EntryIcon?
    let issuerInfo: AuthIssuerInfo?
    let letter: String
    let onPick: (EntryIcon?) -> Void

    init(current: EntryIcon?, issuerInfo: AuthIssuerInfo?, letter: String, onPick: @escaping (EntryIcon?) -> Void) {
        self.current = current
        self.issuerInfo = issuerInfo
        self.letter = letter
        self.onPick = onPick
        if case let .symbol(_, colorHex) = current {
            _symbolColorHex = State(initialValue: colorHex ?? IconPalette.default)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                header
                Picker(selection: $tab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.title, bundle: .module).tag(tab)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, DesignConstant.padding)

                switch tab {
                case .brands:
                    brands
                case .symbols:
                    symbols
                case .picture:
                    picture
                }
            }
            .padding(.top, 8)
            .navigationTitle(Text("Choose an icon", bundle: .module))
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
                }
                .fullScreenMainBackground()
                .errorMessageAlert($errorMessage)
                .fileImporter(isPresented: $showFileImporter,
                              allowedContentTypes: [.image],
                              allowsMultipleSelection: false) { result in
                    handleImport(result)
                }
        }
        #if os(macOS)
        .fontScaled()
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 360, minHeight: 460, idealHeight: 540)
        #endif
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 14) {
            EntryIconView(icon: ResolvedEntryIcon.resolve(override: current,
                                                          issuerInfo: issuerInfo,
                                                          letter: letter,
                                                          catalog: catalog),
                          size: 56,
                          cornerRadius: 14)
                .equatable()
            VStack(alignment: .leading, spacing: 4) {
                Text(current == nil ? "Automatic icon" : "Custom icon", bundle: .module)
                    .dynamicFont(size: 16, textStyle: .callout, weight: .semibold)
                    .foregroundStyle(.textNorm)
                Text("The automatic icon is picked from the issuer name.", bundle: .module)
                    .dynamicFont(size: 13, textStyle: .footnote)
                    .foregroundStyle(.textWeak)
            }
            Spacer()
            if current != nil {
                Button {
                    pick(nil)
                } label: {
                    Text("Reset", bundle: .module)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, DesignConstant.padding)
    }

    private var brands: some View {
        VStack(spacing: 8) {
            searchField
            ScrollView {
                let results = catalog.search(query)
                if results.isEmpty {
                    Text("No brand matches \"\(query)\"", bundle: .module)
                        .foregroundStyle(.textWeak)
                        .padding()
                } else {
                    LazyVGrid(columns: [GridItem](repeating: GridItem(.flexible(), spacing: 8), count: 4),
                              spacing: 12) {
                        ForEach(results) { brand in
                            let isSelected = current == .brand(brand.id)
                            Button {
                                pick(.brand(brand.id))
                            } label: {
                                VStack(spacing: 6) {
                                    EntryIconView(icon: .brand(brand), size: 44, cornerRadius: 10)
                                        .equatable()
                                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(isSelected ? Color.purpleInteraction : .clear, lineWidth: 2))
                                    Text(verbatim: brand.title)
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .foregroundStyle(.textWeak)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: brand.title))
                        }
                    }
                    .padding(.horizontal, DesignConstant.padding)
                    .padding(.bottom, DesignConstant.padding)
                }
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.textWeak)
            TextField(text: $query, prompt: Text("Search brands", bundle: .module)) {
                EmptyView()
            }
            .adaptiveTextFieldStyle()
            .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.textWeak)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.inputBackground)
        .clipShape(.capsule)
        .overlay(Capsule().inset(by: 0.5).stroke(.inputBorder, lineWidth: 1))
        .padding(.horizontal, DesignConstant.padding)
    }

    private var symbols: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ColorPaletteRow(selectedHex: $symbolColorHex)
                LazyVGrid(columns: [GridItem](repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    ForEach(IconSymbols.all, id: \.self) { name in
                        let isSelected: Bool = if case let .symbol(selectedName, _) = current {
                            selectedName == name
                        } else {
                            false
                        }
                        Button {
                            pick(.symbol(name: name, colorHex: symbolColorHex))
                        } label: {
                            EntryIconView(icon: .symbol(name: name, colorHex: symbolColorHex),
                                          size: 44,
                                          cornerRadius: 10)
                                .equatable()
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(isSelected ? Color.purpleInteraction : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: name))
                    }
                }
            }
            .padding(DesignConstant.padding)
        }
    }

    private var picture: some View {
        VStack(spacing: 16) {
            if case let .image(data) = current {
                EntryIconView(icon: .image(data), size: 96, cornerRadius: 22)
                    .equatable()
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundStyle(.textWeak)
                    .frame(height: 96)
            }
            // swiftlint:disable:next line_length
            Text("Pick a PNG, JPEG or other picture from your files. It is scaled down to a small square and stored only on this device.",
                 bundle: .module)
                .multilineTextAlignment(.center)
                .dynamicFont(size: 14, textStyle: .footnote)
                .foregroundStyle(.textWeak)
                .padding(.horizontal, DesignConstant.padding * 2)
            CapsuleButton(title: "Choose a picture…",
                          textColor: .white,
                          style: .borderedFilled,
                          maxWidth: 260) {
                showFileImporter = true
            }
            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func pick(_ icon: EntryIcon?) {
        onPick(icon)
        dismiss()
    }

    private func handleImport(_ result: Result<[URL], any Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            do {
                let data = try IconImageProcessor.makeIconData(from: url)
                pick(.image(data))
            } catch {
                errorMessage = error.localizedDescription
            }

        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }
}
