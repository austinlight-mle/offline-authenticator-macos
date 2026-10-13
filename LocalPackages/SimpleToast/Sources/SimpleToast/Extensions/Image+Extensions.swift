//
//  Image+Extensions.swift
//  
//
//  Created by Martin Lukacs on 08/07/2023.
//

import SwiftUI

extension Image {
     @ViewBuilder
     var topDisplayModifier: some View{
        self
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 20, maxHeight: 20, alignment: .center)
    }
}
