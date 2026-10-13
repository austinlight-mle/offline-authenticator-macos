//
//  ViewModifiers.swift
//  
//
//  Created by Martin Lukacs on 08/07/2023.
//

import SwiftUI

//View Modifier to change the text colors
struct TextForegroundModifier: ViewModifier {
    let color: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let color {
            content
                .foregroundStyle(color)
        } else {
            content
        }
    }
}
