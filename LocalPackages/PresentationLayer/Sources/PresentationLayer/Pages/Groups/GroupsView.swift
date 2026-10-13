//
// GroupsView.swift
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

/// Lets the user create, rename, recolor, reorder and delete groups.
struct GroupsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = GroupsViewModel()
    @State private var editedGroup: EntryGroup?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.groups.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle(Text("Groups", bundle: .module))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar { toolbarContent }
                .fullScreenMainBackground()
                .sheetAlertService()
                .sheet(item: $editedGroup) { group in
                    GroupEditorView(group: group) { updated in
                        await viewModel.save(updated)
                    }
                }
        }
        #if os(macOS)
        .fontScaled()
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 360, minHeight: 400, idealHeight: 480)
        #endif
    }

    private var list: some View {
        List {
            Section {
                ForEach(viewModel.groups) { group in
                    GroupRow(group: group, count: viewModel.count(for: group))
                        .contentShape(.rect)
                        .onTapGesture { editedGroup = group }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.requestDelete(group)
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                        .contextMenu {
                            Button {
                                editedGroup = group
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                viewModel.requestDelete(group)
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                }
                .onMove { source, destination in
                    viewModel.move(fromOffsets: source, toOffset: destination)
                }
            } footer: {
                Text("Drag to reorder. Entries that are not in any group stay available under \"All\".",
                     bundle: .module)
                    .foregroundStyle(.textWeak)
            }
        }
        .scrollContentBackground(.hidden)
        #if os(iOS)
            .environment(\.editMode, .constant(.active))
        #endif
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("No groups yet", bundle: .module)
            } icon: {
                Image(systemName: "folder.badge.plus")
            }
        } description: {
            Text("Create groups such as Work or Personal to organise your codes.", bundle: .module)
        } actions: {
            CapsuleButton(title: "Create a group",
                          textColor: .white,
                          style: .borderedFilled,
                          maxWidth: 260) {
                editedGroup = viewModel.makeNewGroup()
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                if #available(iOS 26, macOS 26, *) {
                    Image(systemName: "xmark")
                        .accessibilityLabel(Text("Close", bundle: .module))
                } else {
                    Text("Close", bundle: .module)
                        .foregroundStyle(.purpleInteraction)
                }
            }
            .adaptiveButtonStyle()
            .keyboardShortcut(.escape, modifiers: [])
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                editedGroup = viewModel.makeNewGroup()
            } label: {
                Image(systemName: "plus")
                    .accessibilityLabel(Text("New group", bundle: .module))
            }
            .adaptiveButtonStyle()
            .keyboardShortcut("n")
        }
    }
}

struct GroupRow: View {
    let group: EntryGroup
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            EntryIconView(icon: .symbol(name: group.symbolName, colorHex: group.colorHex), size: 34)
                .equatable()
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: group.name)
                    .dynamicFont(size: 16, textStyle: .callout, weight: .medium)
                    .foregroundStyle(.textNorm)
                Text("\(count) entries", bundle: .module)
                    .dynamicFont(size: 13, textStyle: .footnote)
                    .foregroundStyle(.textWeak)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.textWeak)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    GroupsView()
}
