//
// GroupFilterBar.swift
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

/// Horizontal list of group chips displayed above the entries. The first chip shows every entry.
struct GroupFilterBar: View {
    @Environment(\.colorScheme) private var colorScheme

    let groups: [EntryGroup]
    let selectedGroupId: String?
    let counts: [String?: Int]
    let onSelect: (String?) -> Void
    let onManage: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(id: nil,
                         title: Text("All", bundle: .module),
                         symbolName: "square.grid.2x2",
                         colorHex: nil,
                         count: counts[String?.none] ?? 0)

                    ForEach(groups) { group in
                        chip(id: group.id,
                             title: Text(verbatim: group.name),
                             symbolName: group.symbolName,
                             colorHex: group.colorHex,
                             count: counts[group.id] ?? 0)
                            .id(group.id)
                    }

                    Button(action: onManage) {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.textWeak)
                            .frame(width: 32, height: 32)
                            .background(chipBackground(selected: false))
                            .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Manage groups", bundle: .module))
                }
                .padding(.horizontal, DesignConstant.padding)
                .padding(.vertical, 6)
            }
            .onAppear {
                if let selectedGroupId {
                    proxy.scrollTo(selectedGroupId, anchor: .center)
                }
            }
        }
        .animation(.default, value: selectedGroupId)
    }

    private func chip(id: String?, title: Text, symbolName: String, colorHex: String?, count: Int) -> some View {
        let selected = id == selectedGroupId
        let tint = colorHex.flatMap { Color(hex: $0) } ?? .purpleInteraction
        return Button {
            onSelect(id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? .white : tint)
                title
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(selected ? .white : .textNorm)
                if count > 0 {
                    Text(verbatim: "\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selected ? Color.white.opacity(0.85) : .textWeak)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(selected ? AnyShapeStyle(tint) : AnyShapeStyle(chipBackground(selected: false)))
            .clipShape(.capsule)
            .overlay(Capsule()
                .inset(by: 0.25)
                .stroke(selected ? .clear : (colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.1)),
                        lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func chipBackground(selected: Bool) -> Color {
        if selected {
            return .purpleInteraction
        }
        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.75)
    }
}
