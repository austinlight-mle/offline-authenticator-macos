//
//  DisplayMode.swift
//  
//
//  Created by Martin Lukacs on 08/07/2023.
//

import Foundation
import SwiftUI

/// Determine how the toast will be displayed
public enum DisplayMode: Equatable, Sendable, Hashable {

    ///Present at the center of the screen
    case center

    ///Drop from the top of the screen
    case top

    ///Banner from the bottom of the view
    case bottom(_ transition: BottomAnimation)
    
    var alignment: Alignment {
        switch self {
        case .center:
            return .center
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }
    
    var transition: AnyTransition {
        switch self {
        case .center:
            AnyTransition.scale(scale: 0.8).combined(with: .opacity)
        case .top:
            AnyTransition.move(edge: .top).combined(with: .opacity)
        case let .bottom(animation):
            animation == .slide ? AnyTransition.slide : AnyTransition.move(edge: .bottom)
        }
    }
}
