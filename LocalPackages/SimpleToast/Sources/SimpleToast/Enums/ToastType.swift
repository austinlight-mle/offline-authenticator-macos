//
//  ToastType.swift
//  
//
//  Created by Martin Lukacs on 08/07/2023.
//

import SwiftUI

/// Determine what the toast will display
public enum ToastType: Sendable, Equatable, Identifiable, Hashable {
    
    ///Animated checkmark
    case complete(_ color: Color)

    ///Animated xmark
    case error(_ color: Color)

    case image(Image)

    ///Loading indicator (Circular)
    case loading

    ///Only text alert
    case regular
    
    public var id: String {
        switch self {
        case .complete:
            "complete"
        case .error:
            "error"
        case .image:
            "image"
        case .loading:
            "loading"
        case .regular:
            "regular"
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .complete(let color):
            hasher.combine("complete")
            hasher.combine(color)
        case .error(let color):
            hasher.combine("error")
            hasher.combine(color)
        case let .image(image):
            hasher.combine("image")
            hasher.combine(String(describing: image))
        case .loading:
            hasher.combine("loading")
        case .regular:
            hasher.combine("regular")
        }
    }
}
