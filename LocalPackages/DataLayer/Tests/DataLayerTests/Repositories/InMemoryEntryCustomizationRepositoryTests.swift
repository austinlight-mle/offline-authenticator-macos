//
// InMemoryEntryCustomizationRepositoryTests.swift
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

@testable import DataLayer
import Models
import Testing

struct InMemoryEntryCustomizationRepositoryTests {
    @Test("Groups are upserted and returned in order")
    func groups() async throws {
        let sut = InMemoryEntryCustomizationRepository()
        try await sut.saveGroup(EntryGroup(id: "b", name: "Work", order: 1))
        try await sut.saveGroup(EntryGroup(id: "a", name: "Home", order: 0))
        try await sut.saveGroup(EntryGroup(id: "b", name: "Office", order: 1))

        let snapshot = try await sut.fetchAll()
        #expect(snapshot.groups.map(\.id) == ["a", "b"])
        #expect(snapshot.groups.last?.name == "Office")
    }

    @Test("Deleting a group detaches its entries and drops empty customizations")
    func deleteGroup() async throws {
        let sut = InMemoryEntryCustomizationRepository()
        try await sut.saveGroup(EntryGroup(id: "work", name: "Work", order: 0))
        try await sut.setCustomization(EntryCustomization(groupId: "work"), for: "entry1")
        try await sut.setCustomization(EntryCustomization(groupId: "work", icon: .brand("google")), for: "entry2")

        try await sut.deleteGroup(id: "work")

        let snapshot = try await sut.fetchAll()
        #expect(snapshot.groups.isEmpty)
        #expect(snapshot.customizations["entry1"] == nil)
        #expect(snapshot.customizations["entry2"] == EntryCustomization(groupId: nil, icon: .brand("google")))
    }

    @Test("Empty customization removes the record")
    func emptyCustomization() async throws {
        let sut = InMemoryEntryCustomizationRepository()
        try await sut.setCustomization(EntryCustomization(icon: .symbol(name: "star.fill", colorHex: nil)), for: "e")
        try await sut.setCustomization(EntryCustomization(), for: "e")
        let snapshot = try await sut.fetchAll()
        #expect(snapshot.customizations.isEmpty)
    }
}
