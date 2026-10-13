//
// IssuerInfo.swift
// Altosec Authenticator - Created on 27/03/2025.
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

public struct AuthIssuerInfo: Sendable, Hashable, Codable {
    public let domain: String
    public let iconUrl: String
    /// Id of a bundled brand icon matching the issuer, usable offline. `nil` when none matches.
    public let brandIconId: String?

    public init(domain: String, iconUrl: String, brandIconId: String? = nil) {
        self.domain = domain
        self.iconUrl = iconUrl
        self.brandIconId = brandIconId
    }
}
