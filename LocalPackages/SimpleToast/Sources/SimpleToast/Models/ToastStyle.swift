//
//  ToastStyle.swift
//  
//
//  Created by Martin Lukacs on 08/07/2023.
//

import SwiftUI

/// Customize Alert Appearance
public struct ToastDisplayStyle: Equatable, Sendable {

    ///Get background color
    let backgroundColor: any ShapeStyle

    /// Get title color
    let titleColor: Color?

    /// Get subTitle color
    let subtitleColor: Color?

    /// Get border color
    let borderColor: Color?

    /// Get title font
    let titleFont: Font

    /// Get subTitle font
    let subTitleFont: Font
    
    let shape: any Shape
    
    let offsetY: CGFloat

    public init(shape: any Shape,
                titleFont: Font = Font.body.bold(),
                subTitleFont: Font = Font.footnote,
                offsetY: CGFloat = 0,
                backgroundColor: any ShapeStyle = .regularMaterial,
                titleColor: Color? = nil,
                subtitleColor: Color? = nil,
                borderColor: Color? = nil) {
        self.shape = shape
        self.offsetY = offsetY
        self.backgroundColor = backgroundColor
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
        self.borderColor = borderColor
        self.titleFont = titleFont
        self.subTitleFont = subTitleFont
    }
    
    public static var `default`: ToastDisplayStyle {
        ToastDisplayStyle(shape: .capsule)
    }
    
    
    public static func == (lhs: ToastDisplayStyle, rhs: ToastDisplayStyle) -> Bool {
        // Compare all Equatable properties
        guard lhs.titleColor == rhs.titleColor,
              lhs.subtitleColor == rhs.subtitleColor,
              lhs.borderColor == rhs.borderColor,
              lhs.titleFont == rhs.titleFont,
              lhs.subTitleFont == rhs.subTitleFont,
              lhs.offsetY == rhs.offsetY else {
            return false
        }
        
        // For the shape, we need a custom comparison
        // This is tricky because we can't directly compare existential types
        // One approach is to compare their string representations or other identifiable information
        return String(describing: lhs.shape) == String(describing: rhs.shape) && String(describing: lhs.backgroundColor) == String(describing: rhs.backgroundColor)
    }
}
