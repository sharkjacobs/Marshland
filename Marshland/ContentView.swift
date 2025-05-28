//
//  ContentView.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: MarshlandDocument

    var body: some View {
        Text(document.attributedText.markdownRepresentation)
    }
}

#Preview {
    ContentView(document: .constant(MarshlandDocument()))
}
