//
// TotpIssuerMapper.swift
// Altosec Authenticator - Created on 26/03/2025.
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

import AuthenticatorRustCore
import CommonUtilities
import Foundation
import Models
#if canImport(UIKit)
import UIKit
#endif

public protocol TOTPIssuerMapperServicing: Sendable {
    func lookup(issuer: String) -> AuthIssuerInfo?
}

/// A library to map TOTP issuer names to domains and icons
public final class TOTPIssuerMapper: TOTPIssuerMapperServicing {
    private let mapper: any AuthenticatorIssuerMapperProtocol
    private let brandIconCatalog: any BrandIconCataloging
    private let cacheProtected: any MutexProtected<[String: AuthIssuerInfo]> = SafeMutex.create([:])

    public init(mapper: any AuthenticatorIssuerMapperProtocol = AuthenticatorIssuerMapper(),
                brandIconCatalog: any BrandIconCataloging = BrandIconCatalog()) {
        self.mapper = mapper
        self.brandIconCatalog = brandIconCatalog
    }

    /// Look up an issuer and return its domain and icon information
    /// - Parameter issuer: The issuer name from the TOTP
    /// - Returns: IssuerInfo containing the domain, the remote icon url and the id of a bundled brand
    /// icon when one matches, or `nil` when nothing is known about the issuer.
    public func lookup(issuer: String) -> AuthIssuerInfo? {
        if let authIssuerInfo = cacheProtected.value[issuer] {
            return authIssuerInfo
        }

        let remoteInfo = mapper.lookup(issuer: issuer)?.toAuthIssuerInfo
        let brandIcon = brandIconCatalog.match(issuer: issuer, domain: remoteInfo?.domain)

        let result: AuthIssuerInfo? = if let remoteInfo {
            AuthIssuerInfo(domain: remoteInfo.domain,
                           iconUrl: remoteInfo.iconUrl,
                           brandIconId: brandIcon?.id)
        } else if let brandIcon {
            AuthIssuerInfo(domain: "", iconUrl: "", brandIconId: brandIcon.id)
        } else {
            nil
        }

        if let result {
            cacheProtected.modify {
                $0[issuer] = result
            }
        }

        return result
    }
}

private extension IssuerInfo {
    var toAuthIssuerInfo: AuthIssuerInfo {
        // Randomising the host to be sure not to be rate limited
        let iconUrl = iconUrl
            .replacingOccurrences(of: "t0.gstatic.com",
                                  with: IconHostEndpoints.randomHost.rawValue)
        return AuthIssuerInfo(domain: domain, iconUrl: iconUrl)
    }
}

private enum IconHostEndpoints: String, CaseIterable, Equatable {
    case one = "t1.gstatic.com"
    case two = "t2.gstatic.com"
    case three = "t3.gstatic.com"

    static var randomHost: Self {
        allCases.randomElement() ?? .one
    }
}
